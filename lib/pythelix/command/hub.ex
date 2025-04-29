defmodule Pythelix.Command.Hub do
  use GenServer

  require Logger

  alias Pythelix.Command.Executor
  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Scripting.Namespace.Extended
  alias Pythelix.Record

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    state = %{
      client_id: 1,
      executor_id: 1,
      queue: :queue.new(),
      busy?: false,
      running: {nil, nil}
    }

    {:ok, state, {:continue, :init_world}}
  end

  def handle_continue(:init_world, state) do
    Pythelix.World.init()

    {:noreply, state}
  end

  def assign_client(from_pid) do
    GenServer.call(__MODULE__, {:assign_client, from_pid})
  end

  def send_command(client_id, command) do
    GenServer.cast(__MODULE__, {:command, client_id, command})
  end

  def handle_call({:assign_client, from_pid}, _from, %{client_id: client_id} = state) do
    parent = Record.get_entity("generic/client")
    key = "client/#{client_id}"

    {:ok, _} = Record.create_entity(virtual: true, key: key, parent: parent)

    Record.set_attribute(key, "client_id", state.client_id)
    Record.set_attribute(key, "pid", from_pid)
    Record.set_attribute(key, "msg", {:extended, Extended.Client, :m_msg})

    {:reply, client_id, %{state | client_id: state.client_id + 1}}
  end

  def handle_cast({:command, client_id, command}, state) do
    if state.busy? do
      queue = :queue.in(state.queue, {:command, client_id, command})

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, run_command(state, client_id, command)}
    end
  end

  def handle_cast({:script, id_or_key, name, args}, state) do
    if state.busy? do
      queue = :queue.in(state.queue, {:script, id_or_key, name, args})

      {:noreply, %{state | queue: queue}}
    else
      {:noreply, run_script(state, id_or_key, name, args)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {running, current_pid} = state.running

    if reason != :normal do
      Logger.error(
        "Executor crashed: #{inspect(reason)} in ID #{running} with PID #{inspect(current_pid)}"
      )
    end

    if pid == current_pid do
      handle_info({:executor_done, running, {:error, reason}}, state)
    else
      {:noreply, state}
    end
  end

  def handle_info({:executor_done, executor_id, result}, state) do
    {running, _} = state.running

    if executor_id == running do
      {next, queue} = :queue.out(state.queue)
      state = %{state | busy?: false, running: {nil, nil}, queue: queue}

      case next do
        {:value, {:command, client_id, command}} ->
          {:noreply, run_command(state, client_id, command)}

        {:value, {:script, id_or_key, name, args}} ->
          {:noreply, run_script(state, id_or_key, name, args)}

        {:value, {:unpause, pid}} ->
          {:noreply, unpause(state, pid)}

        :empty ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  defp run_command(%{executor_id: executor_id} = state, client_id, command) do
    key = "client/#{client_id}"
    client = Record.get_entity(key)
    command_key = "command/#{command}"

    args = %{"client" => client}

    {:ok, pid} =
      Pythelix.Executor.start_child({
        Pythelix.Command.Executor,
        {executor_id, {command_key, args}}
      })

    Process.monitor(pid)
    GenServer.cast(pid, :execute)

    %{state | busy?: true, running: {executor_id, pid}, executor_id: executor_id + 1}
  end

  defp run_script(%{executor_id: executor_id} = state, id_or_key, name, args) do
    with entity = %Entity{} <- Record.get_entity(id_or_key),
         method = %Method{} <- Map.get(entity.methods, name, :no_method) do
      method_args = %{method: method, args: [], kwargs: args}

      {:ok, pid} =
        Pythelix.Executor.start_child({
          Pythelix.Scripting.Executor,
          {executor_id, method_args}
        })

      Process.monitor(pid)
      GenServer.cast(pid, :execute)

      {:ok, %{state | busy?: true, running: {executor_id, pid}, executor_id: executor_id + 1}}
    else
      nil -> {:error, "unknown entity: #{id_or_key}"}
      :no_method -> {:error, "no method #{name} on #{id_or_key}"}
    end
    |> case do
      {:ok, result} ->
        state

      {:error, error} ->
        send(self(), {:executor_done, executor_id, {:error, error}})

        %{state | busy?: false, running: {nil, nil}, executor_id: executor_id + 1}
    end
  end

  defp unpause(state, pid) do
    send(pid, :unpause)
    state
  end
end
