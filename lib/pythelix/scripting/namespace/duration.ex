defmodule Pythelix.Scripting.Namespace.Duration do
  @moduledoc """
  Module defining the duration object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.Duration

  defattr seconds(_script, self) do
    Store.get_value(self).seconds
  end

  defattr minutes(_script, self) do
    Store.get_value(self).minutes
  end

  defattr hours(_script, self) do
    Store.get_value(self).hours
  end

  defattr days(_script, self) do
    Store.get_value(self).days
  end

  defattr months(_script, self) do
    Store.get_value(self).months
  end

  defattr years(_script, self) do
    Store.get_value(self).years
  end

  defmet __repr__(script, namespace), [] do
    {script, format_duration(Store.get_value(namespace.self))}
  end

  defmet __str__(script, namespace), [] do
    {script, format_duration(Store.get_value(namespace.self))}
  end

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet total_seconds(script, namespace), [] do
    duration = Store.get_value(namespace.self)
    {script, Duration.total_seconds(duration)}
  end

  defp format_duration(%Duration{} = d) do
    parts =
      [
        {d.years, "y"},
        {d.months, "o"},
        {d.days, "d"},
        {d.hours, "h"},
        {d.minutes, "m"},
        {d.seconds, "s"}
      ]
      |> Enum.reject(fn {v, _} -> v == 0 end)
      |> Enum.map(fn {v, u} -> "#{v}#{u}" end)
      |> Enum.join()

    if parts == "", do: "0s", else: parts
  end
end
