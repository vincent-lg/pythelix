defmodule Pythelix.Command.Hub do
  use GenServer

  require Logger

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def init(_) do
    state = %{
      client_id: 1,
      executor_id: 1,
      queue: :queue.new(),
      busy?: false,
      running: nil,
      tasks: %{},
      references: %{},
      messages: MapSet.new()
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

      {:noreply, state}
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
    {:ok, state} =
      start_executor(Pythelix.Menu.Connector, state.executor_id, {key}, {:connect, key}, state)

    #send(self(), {:"$gen_cast", {:full, client_id}})

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

  def handle_cast({:unpause, _task_id} = task, state) do
    if state.busy? do
      queue = :queue.in(task, state.queue)

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, execute(task, state)}
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

  def handle_cast({:message, client_id, message, pid}, %{messages: messages} = state) do
    send(pid, {:message, message})
    {:noreply, %{state | messages: MapSet.put(messages, client_id)}}
  end

  def handle_cast({:full, :all, times}, state) do
    if times < 3 do
      Process.send_after(self(), {:"$gen_cast", {:full, :all, times + 1}}, 50)
    end

    {:noreply, send_full_all(state)}
  end

  def handle_cast({:full, client_id}, state) do
    {:noreply, send_full(client_id, state)}
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
    state = send_full_all(state)
    Pythelix.Record.Diff.apply()

    if executor_id == running do
      {next, state} = get_next_task(state)

      case next do
        :empty ->
          {:noreply, state}

        {:task, task} ->
          {:noreply, execute(task, state)}
      end
    else
      {:noreply, state}
    end
  end

  defp execute({:command, client_id, start_time, command} = key, %{executor_id: executor_id} = state) do
    client_key = "client/#{client_id}"
    client = Record.get_entity(client_key)
    menu = (client && Record.get_location_entity(client)) || nil

    if menu == nil do
      state
    else
      args = {menu.key, client, start_time, command}

      {:ok, state} =
        start_executor(Pythelix.Menu.Executor, executor_id, args, key, state)

      state
    end
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

  defp execute({:unpause, task_id} = key, %{executor_id: executor_id} = state) do
    {:ok, state} =
      start_executor(Pythelix.Scripting.Executor, executor_id, %{task_id: task_id}, key, state)
    state
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

  defp get_next_task(%{queue: queue} = state) do
    {next, queue} = :queue.out(queue)

    case next do
      {:value, task} ->
        {{:task, task}, %{state | queue: queue}}

      :empty ->
        {:empty, state}
    end
  end

  defp send_full_all(%{messages: messages} = state) do
    Enum.reduce(messages, state, fn client_id, state ->
      send_full(client_id, state)
    end)
  end

  def send_full(client_id, %{messages: messages} = state) do
    key = "client/#{client_id}"

    case Record.get_entity(key) do
      nil ->
        state

      client ->
        menu = Record.get_location_entity(client)

        prompt =
          case menu do
            nil ->
              ""

            menu ->
              try do
                Method.call_entity(menu, "get_prompt", [client])
              rescue
                exception ->
                  Logger.error(Exception.format(:error, exception, __STACKTRACE__))
                  "error"
              end
          end

        pid = Record.get_attribute(client, "pid")
        send(pid, {:full, prompt})
        %{state | messages: MapSet.delete(messages, client_id)}
    end
  end
end
