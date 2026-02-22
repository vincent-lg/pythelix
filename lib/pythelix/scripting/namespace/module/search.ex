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
      |> apply_limit(limit, container)

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

    case call_namefor(entity, viewer) do
      nil -> get_item_attribute(item, filter)
      result -> result
    end
  end

  # ---------------------------------------------------------------------------
  # __namefor__ calling (supports optional quantity argument)

  @doc false
  # Call __namefor__ on an entity with just a viewer (no quantity).
  # Returns the hook result, or nil if the hook is absent / errored.
  def call_namefor(entity, viewer) do
    case Method.call_entity(entity, "__namefor__", [viewer]) do
      :nomethod -> nil
      :noresult -> nil
      :traceback -> nil
      result -> result
    end
  end

  # Call __namefor__ on an entity with a viewer and quantity.
  # Inspects the method signature to decide whether to pass quantity:
  #   - 2+ positional args (excl. self) → call with [viewer, quantity]
  #   - 1 positional arg → call with [viewer] (quantity ignored)
  #   - :free args → call with [viewer, quantity]
  #   - no method → nil
  # Returns the hook result, or nil if the hook is absent / errored.
  def call_namefor(entity, viewer, quantity) do
    case Record.get_method(entity, "__namefor__") do
      %Method{args: :free} ->
        case Method.call_entity(entity, "__namefor__", [viewer, quantity]) do
          :nomethod -> nil
          :noresult -> nil
          :traceback -> nil
          result -> result
        end

      %Method{args: constraints} when is_list(constraints) ->
        positional_count =
          constraints
          |> Enum.reject(fn {name, _opts} -> name == "self" end)
          |> Enum.count(fn {_name, opts} -> opts[:index] != nil end)

        args = if positional_count >= 2, do: [viewer, quantity], else: [viewer]

        case Method.call_entity(entity, "__namefor__", args) do
          :nomethod -> nil
          :noresult -> nil
          :traceback -> nil
          result -> result
        end

      _ ->
        nil
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

  # Apply a global item budget across all results in order.
  # Non-stackable entities count as 1; stackable entries consume min(qty, remaining) from the budget.
  # Items beyond the budget are dropped; stackables that would be partially taken are trimmed.
  defp apply_limit(items, nil, _container), do: items

  defp apply_limit(items, limit, container) when is_integer(limit) and limit > 0 do
    {result, _remaining} =
      Enum.reduce(items, {[], limit}, fn
        _item, {acc, 0} ->
          {acc, 0}

        %Stackable{} = stackable, {acc, remaining} ->
          qty = min(stackable.quantity, remaining)
          limited = %Stackable{entity: stackable.entity, quantity: qty, location: container}
          {[limited | acc], remaining - qty}

        item, {acc, remaining} ->
          {[item | acc], remaining - 1}
      end)

    Enum.reverse(result)
  end

  defp apply_limit(items, _limit, _container), do: items

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
