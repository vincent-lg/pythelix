defmodule Pythelix.Scripting.Namespace.Module.Names do
  @moduledoc """
  Module defining the names module.

  Provides functions for grouping entities by name, typically for display
  purposes. Works with lists of entities and stackables (e.g., from
  `search.match` or `.contents`).

  Also provides `eval`, `notify`, and `broadcast` for viewer-aware entity
  name resolution and message delivery.
  """

  use Pythelix.Scripting.Module, name: "names"

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Namespace.Module.Search
  alias Pythelix.Stackable

  defmet group(script, namespace), [
    {:items, index: 0, type: :list},
    {:viewer, keyword: "viewer", type: :entity, default: nil},
    {:filter, keyword: "filter", type: :str, default: "name"}
  ] do
    items = Store.get_value(namespace.items)
    viewer = namespace.viewer && Store.get_value(namespace.viewer)
    filter = namespace.filter

    result = group_items(items, viewer, filter)

    {script, result}
  end

  defmet eval(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:viewer, index: 1, type: :entity},
    {:quantity, keyword: "quantity", type: :int, default: 1}
  ] do
    entity = Store.get_value(namespace.entity)
    viewer = Store.get_value(namespace.viewer)
    quantity = namespace.quantity

    result = case Search.call_namefor(entity, viewer, quantity) do
      nil ->
        case Record.get_attribute(entity, "name") do
          name when is_binary(name) -> name
          _ -> inspect(entity)
        end

      name -> name
    end

    {script, result}
  end

  defmet notify(script, namespace), [
    {:entity, index: 0, type: :entity},
    {:text, index: 1, type: :str},
    {:only_visible, keyword: "only_visible", type: :bool, default: true}
  ] do
    entity = Store.get_value(namespace.entity)
    text = namespace.text

    case Record.get_method(entity, "msg") do
      %Method{} ->
        do_notify(entity, text, namespace.only_visible)

      _ -> nil
    end

    {script, :none}
  end

  defmet broadcast(script, namespace), [
    {:location, index: 0, type: :entity},
    {:text, index: 1, type: :str},
    {:auto_exclude, keyword: "auto_exclude", type: :bool, default: true},
    {:only_visible, keyword: "only_visible", type: :bool, default: true}
  ] do
    location = Store.get_value(namespace.location)
    text = namespace.text
    auto_exclude = namespace.auto_exclude
    only_visible = namespace.only_visible

    # Get entity IDs referenced in the f-string (for exclusion)
    referenced_ids =
      Format.String.extract_entities(text)
      |> MapSet.new(fn %Entity{id: id} -> id end)

    contents = Record.get_contained(location)

    for item <- contents do
      entity = get_content_entity(item)

      case Record.get_method(entity, "msg") do
        %Method{} ->
          excluded = auto_exclude && MapSet.member?(referenced_ids, entity.id)

          unless excluded do
            do_notify(entity, text, only_visible)
          end

        _ -> nil
      end
    end

    {script, :none}
  end

  defp do_notify(entity, text, only_visible) do
    {formatted, entities} = Format.String.format_for(text, entity)

    should_send =
      if only_visible do
        Enum.all?(entities, fn e -> entity_visible?(e, entity) end)
      else
        true
      end

    if should_send do
      Method.call_entity(entity, "msg", [formatted])
    end
  end

  defp entity_visible?(entity, viewer) do
    case Method.call_entity(entity, "__visible__", [viewer]) do
      false -> false
      _ -> true
    end
  end

  defp get_content_entity(%Stackable{entity: entity}), do: entity
  defp get_content_entity(%Entity{} = entity), do: entity

  # Groups a list of items by resolved name, preserving first-occurrence order.
  # Returns a list of display names (one per group), where each name is obtained
  # by calling __namefor__(viewer, quantity) on the first entity in the group.
  defp group_items(items, viewer, filter) do
    # Unwrap items that might be store references.
    items = Enum.map(items, &Store.get_value/1)

    # Build ordered groups: [{name, quantity, first_entity}]
    # using the singular name (from __namefor__(viewer) or raw attribute) as grouping key.
    {groups, _seen} =
      Enum.reduce(items, {[], %{}}, fn item, {groups, seen} ->
        name = get_item_name(item, filter, viewer)
        qty = get_item_quantity(item)

        case Map.get(seen, name) do
          nil ->
            # First occurrence of this name — add a new group.
            index = length(groups)
            seen = Map.put(seen, name, index)
            groups = groups ++ [{name, qty, get_item_entity(item)}]
            {groups, seen}

          index ->
            # Accumulate quantity into the existing group.
            {name, existing_qty, entity} = Enum.at(groups, index)
            groups = List.replace_at(groups, index, {name, existing_qty + qty, entity})
            {groups, seen}
        end
      end)

    # For each group, call __namefor__(viewer, quantity) to get the display name.
    Enum.map(groups, fn {raw_name, quantity, entity} ->
      resolve_display_name(entity, viewer, quantity, raw_name)
    end)
  end

  defp get_item_name(item, filter, nil) do
    get_item_attribute(item, filter)
  end

  defp get_item_name(item, filter, viewer) do
    entity = get_item_entity(item)

    case Search.call_namefor(entity, viewer) do
      nil -> get_item_attribute(item, filter)
      result -> result
    end
  end

  # Calls __namefor__(viewer, quantity) on the entity to get the display name.
  # Falls back to the raw name if no viewer or no hook.
  defp resolve_display_name(_entity, nil, _quantity, raw_name), do: raw_name

  defp resolve_display_name(entity, viewer, quantity, raw_name) do
    case Search.call_namefor(entity, viewer, quantity) do
      nil -> raw_name
      result -> result
    end
  end

  defp get_item_entity(%Stackable{entity: entity}), do: entity
  defp get_item_entity(%Entity{} = entity), do: entity

  defp get_item_attribute(%Stackable{entity: entity}, name) do
    Record.get_attribute(entity, name)
  end

  defp get_item_attribute(%Entity{} = entity, name) do
    Record.get_attribute(entity, name)
  end

  defp get_item_quantity(%Stackable{quantity: qty}), do: qty
  defp get_item_quantity(%Entity{}), do: 1
end
