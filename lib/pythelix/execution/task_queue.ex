defmodule Pythelix.Execution.TaskQueue do
  @moduledoc """
  Simple FIFO task queue for independent tasks.
  
  This queue only handles top-level tasks that require new processes:
  - Client commands
  - Menu inputs  
  - Paused script resumptions
  - Cross-package calls (network → scripting)
  
  It does NOT queue nested method calls within the same script execution context.
  """
  
  use GenServer
  
  require Logger
  
  # Client API
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  @doc """
  Enqueue a task for execution.
  
  Tasks are tuples with a type and arguments:
  - {:command, client_id, start_time, command}
  - {:menu_input, menu_key, client, input, start_time}
  - {:script_resume, task_id}
  - {:script_call, entity_key, method_name, args}
  """
  def enqueue(task) do
    GenServer.cast(__MODULE__, {:enqueue, task})
  end
  
  @doc """
  Dequeue the next task. Returns :empty if queue is empty.
  """
  def dequeue() do
    GenServer.call(__MODULE__, :dequeue)
  end
  
  @doc """
  Check if the queue is empty.
  """
  def empty?() do
    GenServer.call(__MODULE__, :empty?)
  end
  
  @doc """
  Get the current queue size.
  """
  def size() do
    GenServer.call(__MODULE__, :size)
  end
  
  # Server Implementation
  
  def init(_) do
    state = %{
      queue: :queue.new(),
      stats: %{
        total_enqueued: 0,
        total_dequeued: 0
      }
    }
    
    {:ok, state}
  end
  
  def handle_cast({:enqueue, task}, %{queue: queue, stats: stats} = state) do
    new_queue = :queue.in(task, queue)
    new_stats = %{stats | total_enqueued: stats.total_enqueued + 1}
    
    Logger.debug("Enqueued task: #{inspect(task)}")
    
    # Notify TaskRunner that work is available
    GenServer.cast(Pythelix.Execution.TaskRunner, :check_queue)
    
    {:noreply, %{state | queue: new_queue, stats: new_stats}}
  end
  
  def handle_call(:dequeue, _from, %{queue: queue, stats: stats} = state) do
    case :queue.out(queue) do
      {{:value, task}, new_queue} ->
        new_stats = %{stats | total_dequeued: stats.total_dequeued + 1}
        Logger.debug("Dequeued task: #{inspect(task)}")
        {:reply, {:ok, task}, %{state | queue: new_queue, stats: new_stats}}
        
      {:empty, _} ->
        {:reply, :empty, state}
    end
  end
  
  def handle_call(:empty?, _from, %{queue: queue} = state) do
    {:reply, :queue.is_empty(queue), state}
  end
  
  def handle_call(:size, _from, %{queue: queue} = state) do
    {:reply, :queue.len(queue), state}
  end
end