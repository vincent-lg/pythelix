defmodule Pythelix.Game.Clock.Virtual do
  @moduledoc """
  A clock that moves only when asked to.

  Time stands still between calls to `advance/1`, and no timer fires on its
  own. `advance/1` moves "now" to each pending timer in due order, delivers
  its message, waits for the receiver to deal with it (and for the game hub
  to run whatever the receiver queued, since that is where ticks and scheduled
  calls do their work), then continues up to the requested moment. A timer
  armed while advancing — the next tick, a call scheduled by the one that
  just ran — is fired in the same pass if it falls within the window.

  There is no jitter: a scenario that says `wait 3h` must see the same ticks
  every time it is played.

  Select it with `config :pythelix, clock: Pythelix.Game.Clock.Virtual` and
  start it; the scenario runner does both.
  """

  @behaviour Pythelix.Game.Clock

  use GenServer

  alias Pythelix.Game.Hub

  defstruct now: 0, timers: [], sequence: 0

  # How long to wait for the hub to finish the work one timer queued.
  @hub_timeout 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl GenServer
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl Pythelix.Game.Clock
  def now_ms, do: GenServer.call(__MODULE__, :now_ms)

  @impl Pythelix.Game.Clock
  def send_after(destination, message, delay) do
    GenServer.call(__MODULE__, {:send_after, destination, message, delay})
  end

  @impl Pythelix.Game.Clock
  def cancel_timer(ref), do: GenServer.call(__MODULE__, {:cancel_timer, ref})

  @impl Pythelix.Game.Clock
  def jitter(_interval_ms), do: 0

  @doc """
  Fire everything due within `duration_ms`, in order, and move "now" past it.

  Runs in the caller's process, so that a receiver arming its next timer
  while we wait for it finds the clock free to answer.
  """
  @impl Pythelix.Game.Clock
  def advance(duration_ms) when is_integer(duration_ms) and duration_ms >= 0 do
    fire_until(now_ms() + duration_ms)
  end

  @doc """
  The timers armed and not yet fired, soonest first, as `{due_ms, message}`.
  """
  @spec pending() :: [{integer(), term()}]
  def pending, do: GenServer.call(__MODULE__, :pending)

  defp fire_until(target) do
    case GenServer.call(__MODULE__, {:pop_due, target}) do
      :done ->
        :ok

      {:fire, destination, message} ->
        deliver(destination, message)
        fire_until(target)
    end
  end

  # Deliver, then wait for the receiver to have handled the message and for the
  # hub to have run what it queued. Either may be gone (a stopped server, a
  # test that didn't start the hub), in which case there is nothing to wait for.
  defp deliver(destination, message) do
    with pid when is_pid(pid) <- resolve(destination) do
      send(pid, message)
      settle(pid)
    end

    with pid when is_pid(pid) <- Process.whereis(Hub) do
      settle(pid)
      Hub.await_idle(Hub, @hub_timeout)
    end

    :ok
  end

  defp resolve(pid) when is_pid(pid), do: pid
  defp resolve(name) when is_atom(name), do: Process.whereis(name)

  # A system message is answered only once everything before it in the
  # mailbox has been handled, which is exactly the wait we want.
  defp settle(pid) do
    :sys.get_state(pid, @hub_timeout)
  catch
    :exit, _ -> :ok
  end

  @impl GenServer
  def handle_call(:now_ms, _from, state), do: {:reply, state.now, state}

  def handle_call({:send_after, destination, message, delay}, _from, state) do
    ref = make_ref()
    timer = {state.now + delay, state.sequence, ref, destination, message}
    timers = Enum.sort_by([timer | state.timers], fn {due, seq, _, _, _} -> {due, seq} end)
    {:reply, ref, %{state | timers: timers, sequence: state.sequence + 1}}
  end

  def handle_call({:cancel_timer, ref}, _from, state) do
    {cancelled, timers} = Enum.split_with(state.timers, fn {_, _, r, _, _} -> r == ref end)

    reply =
      case cancelled do
        [{due, _, _, _, _}] -> max(due - state.now, 0)
        [] -> false
      end

    {:reply, reply, %{state | timers: timers}}
  end

  def handle_call(:pending, _from, state) do
    {:reply, Enum.map(state.timers, fn {due, _, _, _, message} -> {due, message} end), state}
  end

  def handle_call({:pop_due, target}, _from, state) do
    case state.timers do
      [{due, _seq, _ref, destination, message} | rest] when due <= target ->
        {:reply, {:fire, destination, message}, %{state | now: due, timers: rest}}

      _ ->
        {:reply, :done, %{state | now: max(state.now, target)}}
    end
  end
end
