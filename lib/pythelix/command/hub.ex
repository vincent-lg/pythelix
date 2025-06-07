defmodule Pythelix.Command.Hub do
  use GenServer

  require Logger

  alias Pythelix.Command
  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def init(_) do
    state = %{
      client_id: 1,
      commands: %{},
      executor_id: 1,
      queue: :queue.new(),
      busy?: false,
      running: nil,
      tasks: %{},
      references: %{}
    }

    {:ok, state, {:continue, :init_world}}
  end

  def handle_continue(:init_world, state) do
    Pythelix.Record.Diff.init()
    Pythelix.Record.cache_relationships()
    init_start_time = System.monotonic_time(:microsecond)

    if Application.get_env(:pythelix, :worldlets) do
      Pythelix.World.init()
      init_elapsed = System.monotonic_time(:microsecond) - init_start_time
      if Application.get_env(:pythelix, :show_stats) do
        IO.puts("⏱️ World initialized in #{init_elapsed} µs")
      end

      cmd_start_time = System.monotonic_time(:microsecond)
      commands =
        Command.get_command_keys()
        |> tap(fn commands ->
          commands
          |> Enum.map(&Command.build_syntax_pattern/1)
        end)
        |> Enum.flat_map(fn key ->
          key
          |> Command.get_command_names()
          |> Enum.flat_map(fn name ->
            1..String.length(name)
            |> Enum.map(fn len -> {String.slice(name, 0, len), key} end)
          end)
        end)
        |> Enum.into(%{})

      cmd_elapsed = System.monotonic_time(:microsecond) - cmd_start_time
      if Application.get_env(:pythelix, :show_stats) do
        IO.puts("⏱️ Commands loaded in #{cmd_elapsed} µs")
      end

      {:noreply, %{state | commands: commands}}
    else
      {:noreply, state}
    end
    |> tap(fn _ ->
      tasks_start_time = System.monotonic_time(:microsecond)
      Pythelix.Task.Persistent.init()
      number = Pythelix.Task.Persistent.load()
      tasks_elapsed = System.monotonic_time(:microsecond) - tasks_start_time
      if Application.get_env(:pythelix, :show_stats) do
        IO.puts("⏱️ #{number} tasks were loaded in #{tasks_elapsed} µs")
      end
    end)
  end

  def assign_client(from_pid) do
    GenServer.call({:global, __MODULE__}, {:assign_client, from_pid})
  end

  def send_command(client_id, start_time, command) do
    GenServer.cast({:global, __MODULE__}, {:command, client_id, start_time, command})
  end

  def start_task(task_id, args, handler) do
    GenServer.cast({:global, __MODULE__}, {:start, task_id, args, handler})
  end

  def send_task(task_id, message) do
    GenServer.cast({:global, __MODULE__}, {:send_task, task_id, message})
  end

  def handle_call({:assign_client, from_pid}, _from, %{client_id: client_id} = state) do
    parent = Record.get_entity("generic/client")
    key = "client/#{client_id}"

    {:ok, _} = Record.create_entity(virtual: true, key: key, parent: parent)

    Record.set_attribute(key, "client_id", state.client_id)
    Record.set_attribute(key, "pid", from_pid)

    {:reply, client_id, %{state | client_id: state.client_id + 1}}
  end

  def handle_cast({:command, _id, _start, _command} = command, state) do
    if state.busy? do
      queue = :queue.in(command, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(command, state)}
    end
  end

  def handle_cast({:script, _id, _name, _args} = script, state) do
    if state.busy? do
      queue = :queue.in(script, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(script, state)}
    end
  end

  def handle_cast({:unpause, _pid} = script, state) do
    if state.busy? do
      queue = :queue.in(script, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(script, state)}
    end
  end

  def handle_cast({:start, _id, _args, _handler} = task, state) do
    if state.busy? do
      queue = :queue.in(task, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(task, state)}
    end
  end

  def handle_cast({:send_task, _task_id, _message} = task, state) do
    if state.busy? do
      queue = :queue.in(task, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(task, state)}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{running: running} = state) do
    task_id = Map.get(state.references, ref)

    if reason != :normal do
      Logger.error("Executor crashed: #{inspect(reason)} in ID #{running}")
    end

    if running == task_id do
      handle_info({:executor_done, task_id, {:error, reason}}, state)
    else
      {:noreply, state}
    end
  end

  def handle_info({:executor_done, executor_id, _result}, %{running: running} = state) do
    {ref, references} = Map.pop(state.references, executor_id)
    {_, references} = Map.pop(references, ref)
    {_, tasks} = Map.pop(state.tasks, executor_id)
    state = %{state | tasks: tasks, references: references, busy?: false, running: nil}

    if executor_id == running do
      {next, state} = get_next_task(state)

      case next do
        {task, _} ->
          {:noreply, execute(task, state)}

        :empty ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  defp execute({:command, client_id, start_time, command} = key, %{commands: commands} = state) do
    client_key = "client/#{client_id}"
    client = Record.get_entity(client_key)

    {command_name, command_args} =
      case String.split(command, " ", parts: 2) do
        [just_key] -> {just_key, ""}
        [cmd, str] -> {cmd, str}
      end

    command_key = Map.get(commands, command_name)

    {:ok, state} =
      execute_command(state, client, start_time, command_key, command_args, key)

    state
  end

  defp execute({:script, id_or_key, name, args} = key, %{executor_id: executor_id} = state) do
    with entity = %Entity{} <- Record.get_entity(id_or_key),
         method = %Method{} <- Map.get(Record.get_methods(entity), name, :no_method) do
      method_args = %{method: method, args: [], kwargs: args}

      start_executor(Pythelix.Scripting.Executor, executor_id, method_args, key, state)
    else
      nil -> {:error, "unknown entity: #{id_or_key}"}
      :no_method -> {:error, "no method #{name} on #{id_or_key}"}
    end
    |> case do
      {:ok, state} ->
        state

      {:error, error} ->
        send(self(), {:executor_done, executor_id, {:error, error}})

        %{state | busy?: false, running: nil, executor_id: executor_id + 1}
    end
  end

  defp execute({:unpause, task_id} = key, %{executor_id: executor_id} = state) when is_integer(task_id) do
    {:ok, state} =
      start_executor(Pythelix.Scripting.Executor, executor_id, %{task_id: task_id}, key, state)
    state
  end

  defp execute({:unpause, pid}, %{executor_id: executor_id} = state) do
    GenServer.cast(pid, {:unpause, executor_id})
    %{state | executor_id: executor_id + 1}
  end

  defp execute({:start, task_id, args, handler} = key, %{executor_id: executor_id} = state) do
    {:ok, state} =
      start_executor(handler, executor_id, {task_id, args}, key, state)

    state
  end

  defp execute({:send_task, task_id, message}, %{executor_id: executor_id} = state) do
    name = {:via, Registry, {Registry.LongRunning, task_id}}
    GenServer.cast(name, {message, executor_id})
    %{state | busy?: true, running: executor_id, executor_id: executor_id + 1}
  end

  defp execute_command(state, _, _, nil, _, _), do: {:ok, state}

  defp execute_command(%{executor_id: executor_id} = state, client, start_time, command_key, command_args, key) do
    args = {client, start_time, command_key, command_args}

    start_executor(Pythelix.Command.Executor, executor_id, args, key, state)
  end

  defp start_executor(handler, executor_id, args, key, state) do
    {:ok, pid} =
      Pythelix.Executor.start_child({handler, {executor_id, args}})

    ref = Process.monitor(pid)
    GenServer.cast(pid, :execute)

    references = Map.put(state.references, ref, executor_id)
    references = Map.put(references, executor_id, ref)
    tasks = Map.put(state.tasks, executor_id, key)

    state = %{state | busy?: true, running: executor_id, executor_id: executor_id + 1, references: references, tasks: tasks}

    {:ok, state}
  end

  defp get_next_task(%{queue: queue, references: references, tasks: tasks} = state) do
    {next, queue} = :queue.out(queue)

    case next do
      {:value, task_id} ->
        {_reference, references} = Map.pop(references, task_id)
        {task, tasks} = Map.pop(tasks, task_id)
        state = %{state | queue: queue, references: references, tasks: tasks}

        if task == nil do
          get_next_task(state)
        else
          {task, state}
        end

      :empty ->
        {:empty, state}
    end
  end
end
