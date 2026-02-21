defmodule Pythelix.Scripting.Namespace.Module.Search do
  @moduledoc """
  Module defining the search module.
  """

  use Pythelix.Scripting.Module, name: "search"

  import Pythelix.Search, only: [find_many: 1]

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Stackable

  defmet many(script, namespace), [
    {:parent, index: 0, type: :entity, default: nil},
    {:filters, kwargs: true}
  ] do
    case Dict.items(namespace.filters) do
      [] ->
        message = "you should specify at least one keyword argument (a filter)"
        {Script.raise(script, ValueError, message), :none}

      filters ->
        results = compute_many(namespace.parent, filters)
        {script, results}
    end
  end

  defmet one(script, namespace), [
    {:parent, index: 0, type: :entity, default: nil},
    {:filters, kwargs: true}
  ] do
    case Dict.items(namespace.filters) do
      [] ->
        message = "you should specify at least one keyword argument (a filter)"
        {Script.raise(script, ValueError, message), :none}

      filters ->
        results = compute_many(namespace.parent, filters)

        case results do
          [] ->
            {script, :none}

          [result] ->
            {script, result}

          _ ->
            message = "#{length(results)} matching results, expecting 0 or 1"
            {Script.raise(script, ValueError, message), :none}
        end
    end
  end

  defmet match(script, namespace), [
    {:container, index: 0, type: :entity},
    {:text, index: 1, type: :str},
    {:viewer, keyword: "viewer", type: :entity, default: nil},
    {:limit, keyword: "limit", type: :int, default: nil},
    {:index, keyword: "index", type: :int, default: nil},
    {:filter, keyword: "filter", type: :str, default: "name"}
  ] do
    container = Store.get_value(namespace.container)
    text = namespace.text
    viewer = namespace.viewer && Store.get_value(namespace.viewer)
    limit = namespace.limit
    match_index = namespace.index
    filter = namespace.filter

    # Build a normalizer once — uses !search!.normalize if the entity and method exist,
    # otherwise falls back to plain String.downcase.
    normalizer = build_normalizer()
    normalized_text = normalizer.(text)

    contents = Record.get_contained(container)

    results =
      contents
      |> Enum.filter(fn item -> item_visible?(item, viewer) end)
      |> Enum.filter(fn item ->
        attr_value = get_item_name(item, filter, viewer)
        attr_value != nil && matches_normalized?(normalizer.(attr_value), normalized_text)
      end)
      |> maybe_select_index(match_index)
      |> Enum.map(fn item -> maybe_limit_stackable(item, limit, container) end)

    {script, results}
  end

  # ---------------------------------------------------------------------------
  # Normalization

  # Looks for a `normalize` method on the well-known `!search!` entity. If found,
  # returns a closure that delegates to that method; otherwise returns a closure
  # that simply lowercases the input.
  defp build_normalizer do
    search_entity = Record.get_entity("search")

    if search_entity do
      case Record.get_method(search_entity, "normalize") do
        %Method{} ->
          fn text when is_binary(text) ->
            case Method.call_entity(search_entity, "normalize", [text]) do
              result when is_binary(result) -> result
              _ -> String.downcase(text)
            end
          end

        _ ->
          &default_normalize/1
      end
    else
      &default_normalize/1
    end
  end

  defp default_normalize(text) when is_binary(text), do: String.downcase(text)
  defp default_normalize(other), do: other

  # ---------------------------------------------------------------------------
  # Visibility

  # When no viewer is given, all items are visible by default.
  defp item_visible?(_item, nil), do: true

  # When a viewer is provided, call __visible__(viewer) on the item entity if the
  # method exists. Any return value other than an explicit `false` is treated as
  # visible (including :nomethod, :noresult, and :traceback).
  defp item_visible?(item, viewer) do
    entity = get_item_entity(item)

    case Method.call_entity(entity, "__visible__", [viewer]) do
      false -> false
      _ -> true
    end
  end

  # ---------------------------------------------------------------------------
  # Per-viewer name resolution

  # Without a viewer, fall back to the raw attribute value.
  defp get_item_name(item, filter, nil) do
    get_item_attribute(item, filter)
  end

  # With a viewer, call __namefor__(viewer) on the item entity if the method
  # exists. Falls back to the raw attribute value on :nomethod, :noresult, or
  # :traceback.
  defp get_item_name(item, filter, viewer) do
    entity = get_item_entity(item)

    case Method.call_entity(entity, "__namefor__", [viewer]) do
      :nomethod -> get_item_attribute(item, filter)
      :noresult -> get_item_attribute(item, filter)
      :traceback -> get_item_attribute(item, filter)
      result -> result
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers

  defp get_item_entity(%Stackable{entity: entity}), do: entity
  defp get_item_entity(%Entity{} = entity), do: entity

  defp get_item_attribute(%Stackable{entity: entity}, name) do
    Record.get_attribute(entity, name)
  end

  defp get_item_attribute(%Entity{} = entity, name) do
    Record.get_attribute(entity, name)
  end

  # Both sides are already normalised before this check is called.
  defp matches_normalized?(attr_value, text) when is_binary(attr_value) and is_binary(text) do
    String.starts_with?(attr_value, text) || String.contains?(attr_value, text)
  end

  defp matches_normalized?(_, _), do: false

  # Select only the Nth result (1-based). Returns [] when the index is out of range.
  defp maybe_select_index(results, nil), do: results

  defp maybe_select_index(results, index) when is_integer(index) and index >= 1 do
    case Enum.at(results, index - 1) do
      nil -> []
      item -> [item]
    end
  end

  defp maybe_select_index(results, _), do: results

  defp maybe_limit_stackable(%Stackable{} = stackable, limit, container) when is_integer(limit) and limit > 0 do
    qty = min(stackable.quantity, limit)
    %Stackable{entity: stackable.entity, quantity: qty, location: container}
  end

  defp maybe_limit_stackable(item, _limit, _container), do: item

  defp compute_many(nil, filters) do
    filters = Enum.map(filters, &Store.get_value/1)
    find_many(filters)
  end

  defp compute_many(parent, filters) do
    parent = Store.get_value(parent)
    filters = Enum.map(filters, &Store.get_value/1)
    find_many(filters)
    |> Enum.filter(fn result ->
      Record.get_ancestors(result)
      |> Enum.find(fn ancestor -> ancestor == parent end)
    end)
  end
end
