defmodule Pythelix.Game.Calendar do
  @moduledoc """
  Pure computation module for calendar calculations.

  Handles both custom unit-based calendars and Gregorian calendars.
  """

  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict

  @doc """
  Compute unit values from game epoch seconds for a calendar entity.

  For custom calendars, builds a unit hierarchy and computes each unit's value.
  For Gregorian calendars, uses DateTime to get components.
  """
  def compute_units(epoch_seconds, calendar_entity) do
    cal_type = Record.get_attribute(calendar_entity, "type", "custom")
    offset = Record.get_attribute(calendar_entity, "offset", 0)
    adjusted = epoch_seconds + offset

    case cal_type do
      "gregorian" ->
        compute_gregorian_units(adjusted)

      _ ->
        units_dict = Record.get_attribute(calendar_entity, "units")
        compute_custom_units(adjusted, units_dict)
    end
  end

  @doc """
  Compute properties (boundaries and named properties) from unit values.
  """
  def compute_properties(unit_values, calendar_entity) do
    properties_dict = Record.get_attribute(calendar_entity, "properties")

    if properties_dict == nil do
      %{}
    else
      properties_list = get_dict_items(properties_dict)

      Enum.reduce(properties_list, %{}, fn {name, items}, acc ->
        value = compute_list_property_value(items, unit_values)

        if value != nil do
          Map.put(acc, name, value)
        else
          acc
        end
      end)
    end
  end

  @doc """
  Like `compute_units` but applies adjustments first.

  Adjustments is a map of unit_name => amount_to_add.
  """
  def project_units(epoch_seconds, calendar_entity, adjustments) do
    cal_type = Record.get_attribute(calendar_entity, "type", "custom")
    units_dict = Record.get_attribute(calendar_entity, "units")

    # Convert adjustments to seconds
    adjustment_seconds =
      Enum.reduce(adjustments, 0, fn {unit_name, amount}, acc ->
        case cal_type do
          "gregorian" ->
            acc + gregorian_unit_to_seconds(unit_name, amount)

          _ ->
            acc + custom_unit_to_seconds(unit_name, amount, units_dict)
        end
      end)

    adjusted_epoch = epoch_seconds + adjustment_seconds
    {adjusted_epoch, compute_units(adjusted_epoch, calendar_entity)}
  end

  @doc """
  Given unit values, compute the epoch seconds. Inverse of compute_units.
  """
  def game_seconds_from_units(unit_values, calendar_entity) do
    cal_type = Record.get_attribute(calendar_entity, "type", "custom")
    offset = Record.get_attribute(calendar_entity, "offset", 0)

    seconds =
      case cal_type do
        "gregorian" ->
          gregorian_units_to_seconds(unit_values)

        _ ->
          units_dict = Record.get_attribute(calendar_entity, "units")
          custom_units_to_seconds(unit_values, units_dict)
      end

    seconds - offset
  end

  defp compute_custom_units(adjusted_seconds, units_dict) do
    units = get_dict_items(units_dict)
    {cyclic_units, regular_units} = split_cyclic_units(units)
    hierarchy = build_hierarchy(regular_units)

    regular_values =
      Enum.reduce(hierarchy, %{}, fn {name, unit_info}, acc ->
        total_seconds = unit_total_seconds(name, regular_units, hierarchy)
        start = get_sub_entity_attr(unit_info, "__start", 0)

        # The wrapping factor for a unit comes from the child unit that builds on it.
        # e.g., "second" wraps at 60 because "minute" has factor=60.
        # If no child references this unit, it's the top-level and doesn't wrap.
        wrap_factor = find_wrap_factor(name, regular_units)

        value =
          if wrap_factor != nil and wrap_factor > 0 do
            rem(div(adjusted_seconds, total_seconds), wrap_factor) + start
          else
            div(adjusted_seconds, total_seconds) + start
          end

        Map.put(acc, name, value)
      end)

    # Compute cyclic units separately
    Enum.reduce(cyclic_units, regular_values, fn {name, unit_info}, acc ->
      base_ref = get_sub_entity_attr(unit_info, "__base")
      cycle = get_sub_entity_attr(unit_info, "__cycle")
      start = get_sub_entity_attr(unit_info, "__start", 0)
      offset = get_sub_entity_attr(unit_info, "__offset", 0)
      base_total = unit_total_seconds(base_ref, regular_units, hierarchy)

      value = rem(div(adjusted_seconds, base_total) + offset, cycle) + start
      Map.put(acc, name, value)
    end)
  end

  defp split_cyclic_units(units) do
    Enum.split_with(units, fn {_name, info} ->
      get_sub_entity_attr(info, "__cyclic") == true
    end)
  end

  defp find_wrap_factor(unit_name, units) do
    # Find the unit that has __base == unit_name and return its __factor
    Enum.find_value(units, fn {_name, info} ->
      base = get_sub_entity_attr(info, "__base")
      if base == unit_name, do: get_sub_entity_attr(info, "__factor"), else: nil
    end)
  end

  defp build_hierarchy(units) do
    # Topologically sort units from base (seconds) to largest
    # Each unit has __base (what it builds on) and __factor
    units
    |> Enum.sort_by(fn {_name, unit_info} ->
      depth(unit_info, units, 0)
    end)
  end

  defp depth(unit_info, units, count) do
    base_name = get_sub_entity_attr(unit_info, "__name", nil)

    if base_name == "base" do
      count
    else
      base_ref = get_sub_entity_attr(unit_info, "__base")

      case Enum.find(units, fn {name, _} -> name == base_ref end) do
        {_, parent_info} -> depth(parent_info, units, count + 1)
        nil -> count
      end
    end
  end

  defp unit_total_seconds(name, units, hierarchy) do
    case Enum.find(hierarchy, fn {n, _} -> n == name end) do
      {_, unit_info} ->
        base_name = get_sub_entity_attr(unit_info, "__name", nil)

        if base_name == "base" do
          1
        else
          base_ref = get_sub_entity_attr(unit_info, "__base")
          factor = get_sub_entity_attr(unit_info, "__factor", 1)
          parent_seconds = unit_total_seconds(base_ref, units, hierarchy)
          parent_seconds * factor
        end

      nil ->
        1
    end
  end

  defp custom_unit_to_seconds(unit_name, amount, units_dict) do
    units = get_dict_items(units_dict)
    {cyclic_units, regular_units} = split_cyclic_units(units)
    hierarchy = build_hierarchy(regular_units)

    # Check if this is a cyclic unit
    case Enum.find(cyclic_units, fn {name, _} -> name == unit_name end) do
      {_, unit_info} ->
        base_ref = get_sub_entity_attr(unit_info, "__base")
        base_total = unit_total_seconds(base_ref, regular_units, hierarchy)
        base_total * amount

      nil ->
        total = unit_total_seconds(unit_name, regular_units, hierarchy)
        total * amount
    end
  end

  defp custom_units_to_seconds(unit_values, units_dict) do
    units = get_dict_items(units_dict)
    {_cyclic_units, regular_units} = split_cyclic_units(units)
    hierarchy = build_hierarchy(regular_units)

    # Only include regular (non-cyclic) units in the inverse computation
    regular_names = MapSet.new(regular_units, fn {name, _} -> name end)

    Enum.reduce(unit_values, 0, fn {name, value}, acc ->
      if MapSet.member?(regular_names, name) do
        total = unit_total_seconds(name, regular_units, hierarchy)

        start =
          case Enum.find(hierarchy, fn {n, _} -> n == name end) do
            {_, unit_info} -> get_sub_entity_attr(unit_info, "__start", 0)
            nil -> 0
          end

        acc + (value - start) * total
      else
        acc
      end
    end)
  end

  defp compute_gregorian_units(adjusted_seconds) do
    dt = DateTime.from_unix!(adjusted_seconds)

    %{
      "year" => dt.year,
      "month" => dt.month,
      "day" => dt.day,
      "hour" => dt.hour,
      "minute" => dt.minute,
      "second" => dt.second,
      "weekday" => Date.day_of_week(Date.new!(dt.year, dt.month, dt.day))
    }
  end

  defp gregorian_unit_to_seconds(unit_name, amount) do
    case unit_name do
      "second" -> amount
      "minute" -> amount * 60
      "hour" -> amount * 3600
      "day" -> amount * 86400
      "weekday" -> amount * 86400
      _ -> 0
    end
  end

  defp gregorian_units_to_seconds(unit_values) do
    year = Map.get(unit_values, "year", 1970)
    month = Map.get(unit_values, "month", 1)
    day = Map.get(unit_values, "day", 1)
    hour = Map.get(unit_values, "hour", 0)
    minute = Map.get(unit_values, "minute", 0)
    second = Map.get(unit_values, "second", 0)

    {:ok, naive} = NaiveDateTime.new(year, month, day, hour, minute, second)
    {:ok, dt} = DateTime.from_naive(naive, "Etc/UTC")
    DateTime.to_unix(dt)
  end

  # Iterate a list of sub-entities and return the value of the first match.
  defp compute_list_property_value(items, unit_values) when is_list(items) do
    Enum.find_value(items, fn item -> compute_property_value(item, unit_values) end)
  end

  # Fallback: single sub-entity (plain map used in tests).
  defp compute_list_property_value(item, unit_values) do
    compute_property_value(item, unit_values)
  end

  defp compute_property_value(sub_entity, unit_values) do
    # Sub-entity might be a GameTimeBoundary or GameTimeProperty
    unit = get_sub_entity_attr(sub_entity, "__unit")
    unit_value = Map.get(unit_values, unit)

    cond do
      # GameTimeDefault: always matches — used as a fallback at the end of a property list
      get_sub_entity_attr(sub_entity, "__default") == true ->
        get_sub_entity_attr(sub_entity, "__value")

      # GameTimeBoundary: check if unit value falls in [from, to) — inclusive from, exclusive to
      get_sub_entity_attr(sub_entity, "__from") != nil ->
        from_val = get_sub_entity_attr(sub_entity, "__from")
        to_val = get_sub_entity_attr(sub_entity, "__to")
        value = get_sub_entity_attr(sub_entity, "__value")

        if unit_value != nil and unit_value >= from_val and unit_value < to_val do
          value
        else
          nil
        end

      # GameTimeProperty: check if unit value matches index exactly
      get_sub_entity_attr(sub_entity, "__index") != nil ->
        index = get_sub_entity_attr(sub_entity, "__index")
        value = get_sub_entity_attr(sub_entity, "__value")

        if unit_value != nil and unit_value == index do
          value
        else
          nil
        end

      true ->
        nil
    end
  end

  defp get_dict_items(%Dict{} = dict) do
    Dict.items(dict)
  end

  defp get_dict_items(map) when is_map(map) do
    Map.to_list(map)
  end

  defp get_dict_items(_), do: []

  defp get_sub_entity_attr(sub_entity, attr_name, default \\ nil) do
    cond do
      is_struct(sub_entity, Pythelix.SubEntity) ->
        Dict.get(sub_entity.data, attr_name, default)

      is_map(sub_entity) and Map.has_key?(sub_entity, attr_name) ->
        Map.get(sub_entity, attr_name, default)

      is_struct(sub_entity) ->
        Record.get_attribute(sub_entity, attr_name, default)

      true ->
        default
    end
  end
end
