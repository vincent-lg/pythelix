defmodule Pythelix.Scripting.Namespace.RealDateTime do
  @moduledoc """
  Namespace for the RealDateTime object.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.{Duration, RealDateTime}

  defattr year(_script, self) do
    Store.get_value(self).datetime.year
  end

  defattr month(_script, self) do
    Store.get_value(self).datetime.month
  end

  defattr day(_script, self) do
    Store.get_value(self).datetime.day
  end

  defattr hour(_script, self) do
    Store.get_value(self).datetime.hour
  end

  defattr minute(_script, self) do
    Store.get_value(self).datetime.minute
  end

  defattr second(_script, self) do
    Store.get_value(self).datetime.second
  end

  defattr timezone(_script, self) do
    Store.get_value(self).datetime.time_zone
  end

  defattr weekday(_script, self) do
    dt = Store.get_value(self).datetime
    Date.day_of_week(Date.new!(dt.year, dt.month, dt.day))
  end

  defmet __repr__(script, namespace), [] do
    rdt = Store.get_value(namespace.self)
    {script, "<RealDateTime #{format_dt(rdt.datetime)}>"}
  end

  defmet __str__(script, namespace), [] do
    rdt = Store.get_value(namespace.self)
    {script, format_dt(rdt.datetime)}
  end

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet add(script, namespace), [
    {:elapsed, index: 0}
  ] do
    rdt = Store.get_value(namespace.self)
    elapsed = Store.get_value(namespace.elapsed)

    case elapsed do
      %Duration{} = d ->
        {script, RealDateTime.add_seconds(rdt, Duration.total_seconds(d))}

      n when is_integer(n) ->
        {script, RealDateTime.add_seconds(rdt, n)}

      n when is_float(n) ->
        {script, RealDateTime.add_seconds(rdt, trunc(n))}

      _ ->
        {Script.raise(script, TypeError, "add expects an integer, float, or Duration"), :none}
    end
  end

  defmet sub(script, namespace), [
    {:elapsed, index: 0}
  ] do
    rdt = Store.get_value(namespace.self)
    elapsed = Store.get_value(namespace.elapsed)

    case elapsed do
      %Duration{} = d ->
        {script, RealDateTime.add_seconds(rdt, -Duration.total_seconds(d))}

      n when is_integer(n) ->
        {script, RealDateTime.add_seconds(rdt, -n)}

      n when is_float(n) ->
        {script, RealDateTime.add_seconds(rdt, -trunc(n))}

      _ ->
        {Script.raise(script, TypeError, "sub expects an integer, float, or Duration"), :none}
    end
  end

  defmet schedule(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:method, index: 1, type: :str}
  ] do
    rdt = Store.get_value(namespace.self)
    entity = Store.get_value(namespace.entity)
    method = Store.get_value(namespace.method)

    now_unix = System.system_time(:second)
    target_unix = DateTime.to_unix(rdt.datetime)
    delay_seconds = target_unix - now_unix

    if delay_seconds > 0 do
      delay_ms = trunc(delay_seconds * 1000)
      entity_key = entity.key || entity.gen_id

      Cachex.put(:px_tasks, {:scheduled, entity_key, method}, %{
        delay: delay_ms,
        entity: entity_key,
        method: method,
        scheduled_at: System.system_time(:millisecond)
      })

      Process.send_after(self(), {:scheduled_call, entity_key, method}, delay_ms)
    end

    {script, :none}
  end

  @doc false
  def format_dt(%DateTime{} = dt) do
    offset = dt.utc_offset + dt.std_offset
    date = "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)}"
    time = "#{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
    "#{date} #{time}#{format_offset(offset)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")

  defp format_offset(0), do: "Z"
  defp format_offset(seconds) do
    sign = if seconds >= 0, do: "+", else: "-"
    total = abs(seconds)
    h = String.pad_leading(to_string(div(total, 3600)), 2, "0")
    m = String.pad_leading(to_string(div(rem(total, 3600), 60)), 2, "0")
    "#{sign}#{h}:#{m}"
  end
end
