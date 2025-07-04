defmodule Pythelix.Scripting.Namespace.Module.Search do
  @moduledoc """
  Module defining the search module.
  """

  use Pythelix.Scripting.Namespace

  import Pythelix.Search, only: [find_many: 1]

  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict

  defmet many(script, namespace), [
    {:parent, index: 0, type: :entity, default: nil},
    {:filters, kwargs: true}
  ] do
    case Dict.items(namespace.filters) do
      [] ->
        message = "you should specify at least one keyword argument (a filter)"
        {Script.raise(script, ValueError, message), :none}

      filters ->
        results = compute_many(script, namespace.parent, filters)
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
        results = compute_many(script, namespace.parent, filters)

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

  defp compute_many(script, nil, filters) do
    filters = Enum.map(filters, & Script.get_value(script, &1))
    find_many(filters)
  end

  defp compute_many(script, parent, filters) do
    parent = Script.get_value(script, parent)
    filters = Enum.map(filters, & Script.get_value(script, &1))
    find_many(filters)
    |> Enum.filter(fn result ->
      Record.get_ancestors(result)
      |> Enum.find(fn ancestor -> ancestor == parent end)
    end)
  end
end
