defmodule Pythelix.Execution.PauseManager do
  @moduledoc """
  Manages script pauses and resumptions.
  
  This process handles:
  - Timeout-based script resumptions (wait statements)
  - API call pauses that don't freeze the game
  - Parent-child script relationships for nested calls
  - Cross-package coordination (network ↔ scripting)
  
  Key features:
  - Tracks paused scripts with their parent context
  - Schedules resumptions back to TaskQueue
  - Handles API callbacks and async operations
  - Maintains script genealogy for complex call chains
  """
  
  use GenServer
  
  require Logger
  
  alias Pythelix.Execution.TaskQueue
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Task.Persistent, as: Task
  
  defstruct [
    paused_scripts: %{},
    timer_refs: %{},
    parent_relationships: %{},
    stats: %{
      pauses_registered: 0,
      pauses_resumed: 0,
      pauses_expired: 0
    }
  ]
  
  # Client API
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  @doc """
  Register a paused script for later resumption.
  
  Returns a task_id that can be used to resume or cancel the pause.
  """
  def register_pause(expire_at, %Script{} = script, parent_context \\ nil) do
    GenServer.call(__MODULE__, {:register_pause, expire_at, script, parent_context})
  end
  
  @doc """
  Resume a paused script immediately (for API callbacks).
  """
  def resume_script(task_id, result \\ nil) do
    GenServer.cast(__MODULE__, {:resume_script, task_id, result})
  end
  
  @doc """
  Cancel a paused script (cleanup on error).
  """
  def cancel_pause(task_id) do
    GenServer.cast(__MODULE__, {:cancel_pause, task_id})
  end
  
  @doc """
  Register a parent-child relationship for script calls.
  This allows child completion to trigger parent resumption.
  """
  def register_parent_child(parent_task_id, child_task_id) do
    GenServer.cast(__MODULE__, {:register_parent_child, parent_task_id, child_task_id})
  end
  
  @doc """
  Signal that a script call completed, which may resume waiting parents.
  """
  def signal_completion(task_id, result) do
    GenServer.cast(__MODULE__, {:signal_completion, task_id, result})
  end
  
  # Server Implementation
  
  def init(_) do
    state = %__MODULE__{}
    
    # Load any existing paused tasks from persistence
    Process.send_after(self(), :load_persistent_tasks, 10)
    
    {:ok, state}
  end
  
  def handle_call({:register_pause, expire_at, script, parent_context}, _from, state) do
    task_id = generate_task_id()
    
    # Store in persistent storage
    Task.add(expire_at, script.name || "unknown", script.code, script)
    
    # Set up timer for expiration
    delay_ms = max(0, DateTime.diff(expire_at, DateTime.utc_now(), :millisecond))
    timer_ref = Process.send_after(self(), {:expire_task, task_id}, delay_ms)
    
    # Update state
    new_state = %{state |
      paused_scripts: Map.put(state.paused_scripts, task_id, {expire_at, script}),
      timer_refs: Map.put(state.timer_refs, task_id, timer_ref),
      parent_relationships: maybe_add_parent(state.parent_relationships, task_id, parent_context),
      stats: %{state.stats | pauses_registered: state.stats.pauses_registered + 1}
    }
    
    Logger.debug("Registered pause for task #{task_id}, expires at #{expire_at}")
    
    {:reply, task_id, new_state}
  end
  
  def handle_cast({:resume_script, task_id, result}, state) do
    case Map.get(state.paused_scripts, task_id) do
      nil ->
        Logger.warning("Attempted to resume unknown task #{task_id}")
        {:noreply, state}
        
      {_expire_at, script} ->
        # Cancel timer
        timer_ref = Map.get(state.timer_refs, task_id)
        if timer_ref, do: Process.cancel_timer(timer_ref)
        
        # Queue for resumption
        TaskQueue.enqueue({:script_resume, task_id})
        
        # Clean up state
        new_state = %{state |
          paused_scripts: Map.delete(state.paused_scripts, task_id),
          timer_refs: Map.delete(state.timer_refs, task_id),
          stats: %{state.stats | pauses_resumed: state.stats.pauses_resumed + 1}
        }
        
        Logger.debug("Resumed task #{task_id} with result: #{inspect(result)}")
        
        {:noreply, new_state}
    end
  end
  
  def handle_cast({:cancel_pause, task_id}, state) do
    case Map.get(state.paused_scripts, task_id) do
      nil ->
        {:noreply, state}
        
      {_expire_at, script} ->
        # Cancel timer and clean up
        timer_ref = Map.get(state.timer_refs, task_id)
        if timer_ref, do: Process.cancel_timer(timer_ref)
        
        Script.destroy(script)
        Task.del(task_id)
        
        new_state = %{state |
          paused_scripts: Map.delete(state.paused_scripts, task_id),
          timer_refs: Map.delete(state.timer_refs, task_id),
          parent_relationships: remove_from_relationships(state.parent_relationships, task_id)
        }
        
        Logger.debug("Cancelled pause for task #{task_id}")
        
        {:noreply, new_state}
    end
  end
  
  def handle_cast({:register_parent_child, parent_task_id, child_task_id}, state) do
    new_relationships = Map.put(state.parent_relationships, child_task_id, parent_task_id)
    {:noreply, %{state | parent_relationships: new_relationships}}
  end
  
  def handle_cast({:signal_completion, task_id, result}, state) do
    # Check if this task has a parent waiting
    case Map.get(state.parent_relationships, task_id) do
      nil ->
        # No parent, nothing to do
        {:noreply, state}
        
      parent_task_id ->
        # Resume parent with child's result
        handle_cast({:resume_script, parent_task_id, result}, state)
    end
  end
  
  def handle_info({:expire_task, task_id}, state) do
    case Map.get(state.paused_scripts, task_id) do
      nil ->
        {:noreply, state}
        
      {_expire_at, _script} ->
        # Task expired, queue for resumption
        TaskQueue.enqueue({:script_resume, task_id})
        
        new_state = %{state |
          paused_scripts: Map.delete(state.paused_scripts, task_id),
          timer_refs: Map.delete(state.timer_refs, task_id),
          stats: %{state.stats | pauses_expired: state.stats.pauses_expired + 1}
        }
        
        Logger.debug("Task #{task_id} expired and queued for resumption")
        
        {:noreply, new_state}
    end
  end
  
  def handle_info(:load_persistent_tasks, state) do
    # Load any tasks from persistent storage that should resume
    loaded_count = Task.load()
    
    if loaded_count > 0 do
      Logger.info("Loaded #{loaded_count} persistent tasks")
    end
    
    # Schedule existing tasks for resumption if their time has come
    now = DateTime.utc_now()
    
    Task.list_expired(now)
    |> Enum.each(fn task ->
      Logger.debug("Queueing expired persistent task #{task.id}")
      TaskQueue.enqueue({:script_resume, task.id})
    end)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp generate_task_id() do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp maybe_add_parent(relationships, _task_id, nil), do: relationships
  defp maybe_add_parent(relationships, task_id, parent_context) do
    Map.put(relationships, task_id, parent_context)
  end
  
  defp remove_from_relationships(relationships, task_id) do
    relationships
    |> Map.delete(task_id)
    |> Enum.reject(fn {_key, parent_id} -> parent_id == task_id end)
    |> Map.new()
  end
end