defmodule Pythelix.Execution.TaskRunner do
  @moduledoc """
  Central coordinator for task execution.
  
  This process ensures only one top-level task runs at a time to prevent conflicts.
  It spawns ScriptExecutor processes for actual execution and manages their lifecycle.
  
  Key responsibilities:
  - Pull tasks from TaskQueue one at a time
  - Spawn ScriptExecutor processes for task execution
  - Track running tasks and handle completion
  - Coordinate with PauseManager for script resumptions
  """
  
  use GenServer
  
  require Logger
  
  alias Pythelix.Execution.{TaskQueue, ScriptExecutor, PauseManager}
  alias Pythelix.Record
  
  # Client API
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  @doc """
  Submit a command for execution.
  """
  def submit_command(client_id, start_time, command) do
    TaskQueue.enqueue({:command, client_id, start_time, command})
  end
  
  @doc """
  Submit menu input for execution.
  """
  def submit_menu_input(menu_key, client, input, start_time) do
    TaskQueue.enqueue({:menu_input, menu_key, client, input, start_time})
  end
  
  @doc """
  Submit a script method call for execution.
  """
  def submit_script_call(entity_key, method_name, args) do
    TaskQueue.enqueue({:script_call, entity_key, method_name, args})
  end
  
  # Server Implementation
  
  def init(_) do
    state = %{
      busy?: false,
      current_task: nil,
      current_executor: nil,
      executor_id: 1,
      stats: %{
        tasks_completed: 0,
        tasks_failed: 0
      }
    }
    
    # Start checking for tasks immediately
    Process.send_after(self(), :check_queue, 10)
    
    {:ok, state}
  end
  
  def handle_cast(:check_queue, %{busy?: false} = state) do
    case TaskQueue.dequeue() do
      {:ok, task} ->
        {:noreply, execute_task(task, state)}
        
      :empty ->
        # Check again later if no tasks available
        Process.send_after(self(), :check_queue, 100)
        {:noreply, state}
    end
  end
  
  def handle_cast(:check_queue, %{busy?: true} = state) do
    # Already busy, will check queue when current task completes
    {:noreply, state}
  end
  
  def handle_info(:check_queue, state) do
    handle_cast(:check_queue, state)
  end
  
  def handle_info({:executor_completed, executor_id, result}, %{current_executor: executor_id} = state) do
    Logger.debug("Executor #{executor_id} completed with result: #{inspect(result)}")
    
    new_stats = case result do
      {:ok, _} -> %{state.stats | tasks_completed: state.stats.tasks_completed + 1}
      {:error, _} -> %{state.stats | tasks_failed: state.stats.tasks_failed + 1}
    end
    
    # Mark as not busy and check for next task
    new_state = %{state | 
      busy?: false, 
      current_task: nil, 
      current_executor: nil,
      stats: new_stats
    }
    
    GenServer.cast(self(), :check_queue)
    {:noreply, new_state}
  end
  
  def handle_info({:executor_completed, other_id, _result}, state) do
    # Completed executor doesn't match current one - likely a stale message
    Logger.warning("Received completion for executor #{other_id} but current is #{state.current_executor}")
    {:noreply, state}
  end
  
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) when reason != :normal do
    Logger.error("ScriptExecutor process crashed: #{inspect(reason)}")
    
    # Mark as not busy and check for next task
    new_state = %{state | 
      busy?: false, 
      current_task: nil, 
      current_executor: nil,
      stats: %{state.stats | tasks_failed: state.stats.tasks_failed + 1}
    }
    
    GenServer.cast(self(), :check_queue)
    {:noreply, new_state}
  end
  
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    # Normal shutdown, already handled by :executor_completed
    {:noreply, state}
  end
  
  # Private Functions
  
  defp execute_task(task, %{executor_id: executor_id} = state) do
    Logger.debug("Executing task: #{inspect(task)}")
    
    # Spawn ScriptExecutor process
    {:ok, pid} = ScriptExecutor.start_link(executor_id, task, self())
    Process.monitor(pid)
    
    %{state | 
      busy?: true,
      current_task: task,
      current_executor: executor_id,
      executor_id: executor_id + 1
    }
  end
end