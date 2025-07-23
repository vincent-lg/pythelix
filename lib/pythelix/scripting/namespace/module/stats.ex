defmodule Pythelix.Scripting.Namespace.Module.Stats do
  @moduledoc """
  Module defining the stats module.
  """

  @units ["B", "KB", "MB", "GB", "TB"]

  use Pythelix.Scripting.Module, name: "stats"

  alias Pythelix.Scripting.Store

  defattr number_of_scripts(_script, _) do
    Store.get_number_of_scripts()
  end

  defattr number_of_references(_script, _) do
    Store.get_number_of_references()
  end

  defattr memory_of_scripts(_script, _) do
    Store.get_memory_of_scripts()
  end

  defattr memory_of_references(_script, _) do
    Store.get_memory_of_references()
  end

  defattr number_of_processes(_script, _) do
    :erlang.system_info(:process_count)
  end

  defattr number_of_ports(_script, _) do
    :erlang.system_info(:port_count)
  end

  defattr memory_used(_script, _) do
    :erlang.memory()[:total]
  end

  defattr number_of_processors(_script, _) do
    :erlang.system_info(:logical_processors_available)
  end

  defattr number_of_schedulers(_script, _) do
    :erlang.system_info(:schedulers)
  end

  defattr number_of_tcp_connections(_script, _) do
    DynamicSupervisor.count_children(Pythelix.Network.TCP.ClientSupervisor)[:active]
  end

  defmet human_size(script, namespace), [
    {:size, index: 0, type: :int}
  ] do
    if namespace.size < 0 do
      message = "the specifieid size has to be positive or nil, #{namespace.size} given"

      {Script.raise(script, TypeError, message), :none}
    else
      {script, human_size(namespace.size)}
    end
  end

  def human_size(bytes) when is_integer(bytes) and bytes >= 0 do
    human_size(bytes * 1.0, 0)
  end

  defp human_size(size, unit_idx) when size < 1024 or unit_idx == length(@units) - 1 do
    unit = Enum.at(@units, unit_idx)
    display =
      if size < 5 and unit_idx > 0 do
        Float.round(size, 1)
      else
        round(size)
      end

    "#{display} #{unit}"
  end

  defp human_size(size, unit_idx) do
    human_size(size / 1024, unit_idx + 1)
  end
end
