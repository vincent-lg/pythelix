defmodule Pythelix.Scenario.Collector do
  @moduledoc """
  Stands in for one player's socket.

  A client entity sends its output to a pid (see
  `Pythelix.Game.Hub.mark_client_with_message/4`). For a real player that pid
  is the TCP process; for a scenario it is one of these, which simply keeps
  what it is told.

  One per player, so that "Alice sees" and "Bob sees" are separate questions.
  The buffer is cleared when a player types, not when it is read: every
  expectation after an input is asking about that same exchange, and they must
  all be able to see it.
  """

  @doc """
  Start a collector, linked to the caller.
  """
  @spec start() :: pid()
  def start, do: spawn_link(fn -> loop([]) end)

  @doc """
  Everything received since the last `clear/1`, in order.

  Waits for the exchange to go quiet before answering, so that messages still
  in flight are not missed. `settle` is how long to wait for the first message;
  once something has arrived, a shorter pause catches the rest.
  """
  @spec peek(pid(), pos_integer()) :: [binary()]
  def peek(collector, settle) do
    ref = make_ref()
    send(collector, {:peek, self(), ref, settle})

    receive do
      {^ref, messages} -> messages
    after
      settle * 4 + 1_000 -> []
    end
  end

  @doc """
  Forget everything received so far.
  """
  @spec clear(pid()) :: :ok
  def clear(collector) do
    send(collector, :clear)

    :ok
  end

  @doc """
  Stop the collector.
  """
  @spec stop(pid()) :: :ok
  def stop(collector) do
    send(collector, :stop)

    :ok
  end

  defp loop(received) do
    receive do
      {:message, text} ->
        loop([to_string(text) | received])

      {:full, text} ->
        loop([to_string(text) | received])

      {:peek, from, ref, settle} ->
        received = settle(received, settle)
        send(from, {ref, Enum.reverse(received)})
        loop(received)

      :clear ->
        loop([])

      :stop ->
        :ok

      _other ->
        loop(received)
    end
  end

  # Keep reading until the exchange goes quiet.
  defp settle(received, settle) do
    receive do
      {:message, text} -> settle([to_string(text) | received], settle)
      {:full, text} -> settle([to_string(text) | received], settle)
    after
      wait(received, settle) -> received
    end
  end

  defp wait([], settle), do: settle
  defp wait(_received, _settle), do: 20
end
