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
      # <--- SUPER important!
      restart: :transient,
      type: :worker
    }
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast(:execute, {handler, {executor_id, args}}) do
    process(executor_id, handler, args)
  end

  # def handle_cast(:unpause, {handler, args}) do
  #  process(handler, args)
  # end

  def process(executor_id, handler, args) do
    case handler.execute(args) do
      {:ok, _} ->
        {:stop, :normal, {handler, {executor_id, args}}}

      {:pause, ms} ->
        Process.send_after(Pythelix.Command.Hub, {:unpause, self()}, ms)

        {:noreply, {handler, {executor_id, args}}}
    end
  end
end
