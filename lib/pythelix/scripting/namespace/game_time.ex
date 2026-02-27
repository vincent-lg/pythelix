defmodule Pythelix.Scripting.Namespace.GameTime do
  @moduledoc """
  Namespace for the GameTime object.

  Custom getattr that checks units map, then properties map,
  then falls back to standard methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Game.{Calendar, Epoch}
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Object.{Dict, GameTime}

  defmet __repr__(script, namespace), [] do
    gt = Store.get_value(namespace.self)

    parts =
      gt.units
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join(", ")

    {script, "<GameTime #{parts}>"}
  end

  defmet __str__(script, namespace), [] do
    gt = Store.get_value(namespace.self)

    parts =
      gt.units
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join(", ")

    {script, parts}
  end

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet __calendar__(script, namespace), [] do
    gt = Store.get_value(namespace.self)
    {script, gt.calendar}
  end

  defmet project(script, namespace), [
    {:kwargs, kwargs: true}
  ] do
    gt = Store.get_value(namespace.self)

    adjustments =
      namespace.kwargs
      |> Dict.items()
      |> Enum.reject(fn {k, _} -> k == "self" end)
      |> Map.new(fn {k, v} -> {k, Store.get_value(v)} end)

    {adjusted_epoch, units} = Calendar.project_units(gt.epoch, gt.calendar, adjustments)
    properties = Calendar.compute_properties(units, gt.calendar)

    new_gt = %GameTime{
      calendar: gt.calendar,
      epoch: adjusted_epoch,
      units: units,
      properties: properties
    }

    {script, new_gt}
  end

  defmet schedule(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:method, index: 1, type: :str}
  ] do
    gt = Store.get_value(namespace.self)
    entity = Store.get_value(namespace.entity)
    method = Store.get_value(namespace.method)

    real_delay = Epoch.real_seconds_until(gt.epoch)

    if real_delay > 0 do
      delay_ms = trunc(real_delay * 1000)
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

  # Override getattr to check units and properties first
  def getattr(script, self, name) do
    gt = Store.get_value(self)

    cond do
      Map.has_key?(gt.units, name) ->
        Map.get(gt.units, name)

      Map.has_key?(gt.properties, name) ->
        Map.get(gt.properties, name)

      attr = Map.get(attributes(), name) ->
        apply(__MODULE__, attr, [script, self])

      method = Map.get(methods(), name) ->
        %Callable{module: __MODULE__, object: self, name: method}

      true ->
        message = "'gametime' doesn't have attribute '#{name}'"
        Script.raise(script, AttributeError, message)
    end
  end
end
