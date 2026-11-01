defmodule Pythelix.Game.Clock do
  @moduledoc """
  Where the game reads the time and arms its timers.

  Everything that waits for time to pass — ticks, scheduled one-off calls —
  goes through this module rather than through `System` and `Process`
  directly, so that the clock can be swapped. Two implementations exist:

    * `Pythelix.Game.Clock.Real` — the default. Monotonic time, real timers,
      ±10% jitter on tick intervals.
    * `Pythelix.Game.Clock.Virtual` — a clock that only moves when told to.
      `advance/1` fires every timer due, in order, and returns at once. This
      is what lets a scenario say `wait 3h` and check the crop afterwards
      without taking three hours, and what `mix test` uses to cover ticking.

  The implementation is chosen by the `:clock` application setting. Reading
  it on every call (rather than once at start) means a test can switch clocks
  for its own duration and every timer armed from then on follows.
  """

  @type destination :: pid() | atom()

  @doc "Monotonic time, in milliseconds."
  @callback now_ms() :: integer()

  @doc "Deliver `message` to `destination` after `delay` milliseconds."
  @callback send_after(destination(), term(), non_neg_integer()) :: reference()

  @doc "Cancel a timer armed with `send_after/3`."
  @callback cancel_timer(reference()) :: term()

  @doc "A random offset to add to a tick interval, in milliseconds."
  @callback jitter(non_neg_integer()) :: integer()

  @doc "Move the clock forward, firing what comes due; only a virtual clock can."
  @callback advance(non_neg_integer()) :: :ok | {:error, :real_clock}

  @doc """
  The clock in use, from the `:clock` application setting.
  """
  @spec current() :: module()
  def current, do: Application.get_env(:pythelix, :clock, __MODULE__.Real)

  @spec now_ms() :: integer()
  def now_ms, do: current().now_ms()

  @spec send_after(destination(), term(), non_neg_integer()) :: reference()
  def send_after(destination, message, delay),
    do: current().send_after(destination, message, delay)

  @spec cancel_timer(reference()) :: term()
  def cancel_timer(ref), do: current().cancel_timer(ref)

  @spec jitter(non_neg_integer()) :: integer()
  def jitter(interval_ms), do: current().jitter(interval_ms)

  @doc """
  Move the clock forward by `duration_ms`, firing every timer that comes due.

  Returns `{:error, :real_clock}` under the real clock, which cannot be
  hurried.
  """
  @spec advance(non_neg_integer()) :: :ok | {:error, :real_clock}
  def advance(duration_ms), do: current().advance(duration_ms)
end
