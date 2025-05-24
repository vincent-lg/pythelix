defmodule Pythelix.Task do
  @moduledoc """
  Central module to host Pythelix tasks outside of Mix Tasks to improve maintenability.
  """

  def wait_for_global(name, timeout \\ 1000, interval \\ 100) do
    start_time = System.monotonic_time(:millisecond)
    do_wait(name, start_time, timeout, interval)
  end

  defp do_wait(name, start_time, timeout, interval) do
    case :global.whereis_name(name) do
      :undefined ->
        if System.monotonic_time(:millisecond) - start_time < timeout do
          Process.sleep(interval)
          do_wait(name, start_time, timeout, interval)
        else
          nil
        end

      pid when is_pid(pid) ->
        pid
    end
  end
end
