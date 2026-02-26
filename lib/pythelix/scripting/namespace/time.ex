defmodule Pythelix.Scripting.Namespace.Time do
  @moduledoc """
  Module defining the time object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.{Duration, Time}

  defattr hour(_script, self) do
    Store.get_value(self).hour
  end

  defattr minute(_script, self) do
    Store.get_value(self).minute
  end

  defattr second(_script, self) do
    Store.get_value(self).second
  end

  defmet __repr__(script, namespace), [] do
    {script, format_time(Store.get_value(namespace.self))}
  end

  defmet __str__(script, namespace), [] do
    {script, format_time(Store.get_value(namespace.self))}
  end

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet add(script, namespace), [
    {"elapsed", index: 0}
  ] do
    time = Store.get_value(namespace.self)
    elapsed = Store.get_value(namespace["elapsed"])

    total =
      case elapsed do
        %Duration{} = d ->
          time_to_seconds(time) + Duration.total_seconds(d)

        n when is_integer(n) ->
          time_to_seconds(time) + n

        _ ->
          nil
      end

    case total do
      nil ->
        message = "add expects an integer or Duration"
        {Script.raise(script, TypeError, message), :none}

      total ->
        total = rem(rem(total, 86400) + 86400, 86400)
        new_time = seconds_to_time(total)
        {script, new_time}
    end
  end

  defmet difference(script, namespace), [
    {"with_time", index: 0}
  ] do
    time = Store.get_value(namespace.self)
    other = Store.get_value(namespace["with_time"])

    case other do
      %Time{} ->
        diff = abs(time_to_seconds(time) - time_to_seconds(other))
        hours = div(diff, 3600)
        remaining = rem(diff, 3600)
        minutes = div(remaining, 60)
        seconds = rem(remaining, 60)
        {script, %Duration{hours: hours, minutes: minutes, seconds: seconds}}

      _ ->
        message = "difference expects a Time"
        {Script.raise(script, TypeError, message), :none}
    end
  end

  defp format_time(%Time{hour: h, minute: m, second: 0}) do
    pad(h) <> ":" <> pad(m)
  end

  defp format_time(%Time{hour: h, minute: m, second: s}) do
    pad(h) <> ":" <> pad(m) <> ":" <> pad(s)
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")

  defp time_to_seconds(%Time{hour: h, minute: m, second: s}) do
    h * 3600 + m * 60 + s
  end

  defp seconds_to_time(total) do
    h = div(total, 3600)
    remaining = rem(total, 3600)
    m = div(remaining, 60)
    s = rem(remaining, 60)
    %Time{hour: h, minute: m, second: s}
  end
end
