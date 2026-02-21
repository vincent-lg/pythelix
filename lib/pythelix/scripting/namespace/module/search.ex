defmodule Pythelix.Scripting.Namespace.Module.Search do
  @moduledoc """
  Module defining the search module.
  """

  use Pythelix.Scripting.Module, name: "search"

  import Pythelix.Search, only: [find_many: 1]

  alias Pythelix.Entity
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
    {:limit, keyword: "limit", type: :int, default: nil},
    {:filter, keyword: "filter", type: :str, default: "name"}
  ] do
    container = Store.get_value(namespace.container)
    text = namespace.text
    limit = namespace.limit
    filter = namespace.filter

    text = if is_binary(text), do: String.downcase(text), else: text

    contents = Record.get_contained(container)

    results =
      contents
      |> Enum.filter(fn item ->
        attr_value = get_item_attribute(item, filter)
        attr_value != nil && matches_text?(attr_value, text)
      end)
      |> Enum.map(fn item ->
        maybe_limit_stackable(item, limit, container)
      end)

    {script, results}
  end

  defp get_item_attribute(%Stackable{entity: entity}, name) do
    Record.get_attribute(entity, name)
  end

  defp get_item_attribute(%Entity{} = entity, name) do
    Record.get_attribute(entity, name)
  end

  defp matches_text?(attr_value, text) when is_binary(attr_value) do
    lower = String.downcase(attr_value)
    String.starts_with?(lower, text) || String.contains?(lower, text)
  end

  defp matches_text?(_, _), do: false

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
