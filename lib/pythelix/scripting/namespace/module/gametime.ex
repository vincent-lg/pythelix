defmodule Pythelix.Scripting.Namespace.Module.Gametime do
  @moduledoc """
  Module defining the gametime module for Pythello scripting.

  Provides access to the game clock and calendar system.
  """

  use Pythelix.Scripting.Module, name: "gametime"

  alias Pythelix.Game.{Calendar, Epoch}
  alias Pythelix.Record
  alias Pythelix.Scripting.Object.{GameTime, RealDateTime}

  defattr clock(_script, _self) do
    Epoch.get_clock()
  end

  defmet now(script, namespace), [
    {:calendar, index: 0, default: :none}
  ] do
    calendar_ref = namespace.calendar

    case resolve_calendar(script, calendar_ref) do
      {:ok, calendar_entity} ->
        epoch = Epoch.get_clock()
        units = Calendar.compute_units(epoch, calendar_entity)
        properties = Calendar.compute_properties(units, calendar_entity)

        gt = %GameTime{
          calendar: calendar_entity,
          epoch: epoch,
          units: units,
          properties: properties
        }

        {script, gt}

      {:error, message} ->
        {Script.raise(script, RuntimeError, message), :none}
    end
  end

  defmet from_realtime(script, namespace), [
    {:dt, index: 0},
    {:calendar, index: 1, default: :none}
  ] do
    rdt = Store.get_value(namespace.dt)
    calendar_ref = namespace.calendar

    case {rdt, resolve_calendar(script, calendar_ref)} do
      {%RealDateTime{datetime: dt}, {:ok, calendar_entity}} ->
        scale = Epoch.get_scale()
        started_at = Epoch.get_started_at()

        if started_at == nil do
          message = "game epoch is not configured"
          {Script.raise(script, RuntimeError, message), :none}
        else
          dt_unix = DateTime.to_unix(dt)
          game_epoch = trunc((dt_unix - started_at) * scale)
          units = Calendar.compute_units(game_epoch, calendar_entity)
          properties = Calendar.compute_properties(units, calendar_entity)

          gt = %GameTime{
            calendar: calendar_entity,
            epoch: game_epoch,
            units: units,
            properties: properties
          }

          {script, gt}
        end

      {_, {:error, message}} ->
        {Script.raise(script, RuntimeError, message), :none}

      _ ->
        message = "from_realtime expects a RealDateTime"
        {Script.raise(script, TypeError, message), :none}
    end
  end

  defmet reset_to_zero(script, _namespace), [] do
    Epoch.reset()
    {script, :none}
  end

  defp resolve_calendar(_script, calendar_ref) when calendar_ref == :none do
    calendars = Epoch.get_calendars()

    case length(calendars) do
      0 -> {:error, "no calendar defined"}
      1 -> {:ok, hd(calendars)}
      _ -> {:error, "multiple calendars exist, specify which one"}
    end
  end

  defp resolve_calendar(_script, calendar_ref) do
    calendar = Store.get_value(calendar_ref)

    case calendar do
      %Pythelix.Entity{} = entity ->
        {:ok, entity}

      key when is_binary(key) ->
        case Record.get_entity(key) do
          nil -> {:error, "calendar '#{key}' not found"}
          entity -> {:ok, entity}
        end

      _ ->
        {:error, "invalid calendar reference"}
    end
  end
end
