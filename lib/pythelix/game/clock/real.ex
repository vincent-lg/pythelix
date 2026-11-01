defmodule Pythelix.Game.Clock.Real do
  @moduledoc """
  The real clock: `System` for the time, `Process` for the timers.
  """

  @behaviour Pythelix.Game.Clock

  @impl true
  def now_ms, do: System.monotonic_time(:millisecond)

  @impl true
  def send_after(destination, message, delay),
    do: Process.send_after(destination, message, delay)

  @impl true
  def cancel_timer(ref), do: Process.cancel_timer(ref)

  # ±10% jitter on the interval, so that entities registered together drift
  # apart rather than all firing in the same instant forever.
  @impl true
  def jitter(interval_ms) do
    range = div(interval_ms, 10)

    if range > 0 do
      :rand.uniform(range * 2 + 1) - range - 1
    else
      0
    end
  end

  @impl true
  def advance(_duration_ms), do: {:error, :real_clock}
end
