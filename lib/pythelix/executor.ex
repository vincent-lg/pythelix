defmodule Pythelix.Executor do
  @moduledoc """
  A GenServer to execute a script.

  It relies on the command hub. If it's paused, then it should send
  a message to the command hub to be restarted later.
  """

  use GenServer

  def start_child(args) do
    DynamicSupervisor.start_child(Pythelix.ExecutorSupervisor, {__MODULE__, args})
  end

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient,
      type: :worker
    }
  end

  def start_link({handler, args} = state) do
    name = handler.name(args)
    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast(:execute, {handler, {executor_id, args}}) do
    process(executor_id, handler, args)
  end

  def handle_cast({other, executor_id}, {handler, {_id, args}}) do
    case handler.handle_cast(other, executor_id, args) do
      {:noreply, args} ->
        {:noreply, {handler, {executor_id, args}}}

      {:stop, reason, args} ->
        {:stop, reason, {handler, {executor_id, args}}}
    end
  end

  def process(executor_id, handler, args) do
    case handler.execute(executor_id, args) do
      :keep ->
        {:noreply, {handler, {executor_id, args}}}

      {:ok, _} ->
        {:stop, :normal, {handler, {executor_id, args}}}

      {:pause, ms} ->
        Process.send_after({:global, Pythelix.Command.Hub}, {:unpause, self()}, ms)

        {:noreply, {handler, {executor_id, args}}}
    end
  end
end
