defmodule Pythelix.Scripting.Namespace.Dict do
  @moduledoc """
  Module defining the dict object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Object.Dict

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false) |> Dict.keys()
    {script, Enum.member?(list, namespace.element)}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __getitem__(script, namespace), [
    {:item, index: 0, type: :any}
  ] do
    dict = Store.get_value(namespace.self, recursive: false)

    case Dict.get(dict, namespace.item, nil) do
      nil ->
        message = inspect(namespace.item)
        {Script.raise(script, KeyError, message), :none}

      value ->
        {script, value}
    end
  end

  defmet __setitem__(script, namespace), [
    {:item, index: 0, type: :any},
    {:value, index: 1, type: :any}
  ] do
    dict = Store.get_value(namespace.self, recursive: false)

    dict = Dict.put(dict, namespace.item, namespace.value)

    Store.update_reference(namespace.self, dict)

    {script, :none}
  end

  defmet clear(script, namespace), [] do
    dict = Dict.new()
    Store.update_reference(namespace.self, dict)

    {script, :none}
  end

  defmet copy(script, namespace), [] do
    dict = Store.get_value(namespace.self)

    # Returning it will actually create a new reference, akin to a
    # deepcopy due to the nature of Elixir.
    {script, dict}
  end

  defmet get(script, namespace), [
    {:key, index: 0, type: :any},
    {:value, index: 1, type: :any, default: :none}
  ] do
    dict = Store.get_value(namespace.self, recursive: false)

    {script, Dict.get(dict, namespace.key, namespace.value)}
  end

  defmet items(script, namespace), [] do
    dict = Store.get_value(namespace.self)
    items =
      dict
      |> Dict.items()
      |> Enum.map(fn {key, value} -> [key, value] end)

    {script, items}
  end

  defmet keys(script, namespace), [] do
    dict = Store.get_value(namespace.self)
    {script, Dict.keys(dict)}
  end

  defmet pop(script, namespace), [
    {:key, index: 0, type: :any},
    {:default, index: 1, type: :any, default: :unset}
  ] do
    dict = Store.get_value(namespace.self)
    key = Store.get_value(namespace.key)

    case Dict.pop(dict, key, namespace.default) do
      {:unset, _} ->
        {Script.raise(script, KeyError, key), :none}

      {other, dict} ->
        Store.update_reference(namespace.self, dict)

        {script, other}
    end
  end

  defmet popitem(script, namespace), [] do
    dict = Store.get_value(namespace.self)
    case Dict.popitem(dict) do
      :empty ->
        message = "popitem(): dictionary is empty"

        {Script.raise(script, KeyError, message), :none}

      {key, value, dict} ->
        Store.update_reference(namespace.self, dict)

        {script, [key, value]}
    end
  end

  defmet setdefault(script, namespace), [
    {:key, index: 0, type: :any},
    {:default, index: 1, type: :any, default: :none}
  ] do
    dict = Store.get_value(namespace.self)
    key = Store.get_value(namespace.key)

    case Dict.get(dict, key, :unset) do
      :unset ->
        dict = Dict.put(dict, key, namespace.default)

        Store.update_reference(namespace.self, dict)

        {script, namespace.default}

      value ->
        {script, value}
    end
  end

  defmet update(script, namespace), [
    {:dict, index: 0, type: :dict, default: :none},
    {:kwargs, kwargs: true}
  ] do
    dict = Store.get_value(namespace.self)
    to_use = Store.get_value(namespace.dict)

    case to_use do
      :none ->
        dict =
          dict
          |> Dict.update(namespace.kwargs)

        Store.update_reference(namespace.self, dict)

        script

      other ->
        dict =
          dict
          |> Dict.update(other)
          |> Dict.update(namespace.kwargs)

        Store.update_reference(namespace.self, dict)

        script
    end
    |> then(& {&1, :none})
  end

  defmet values(script, namespace), [] do
    dict = Store.get_value(namespace.self)

    {script, Dict.values(dict)}
  end

  defp repr(script, self) do
    Store.get_value(self)
    |> Dict.items()
    |> Enum.map(fn
      {:ellipsis, :ellipsis} -> "...: {...}"
      {key, :ellipsis} -> "#{Display.repr(script, key)}: {...}"
      {:ellipsis, value} -> "...: #{Display.repr(script, value)}"
      {key, value} -> "#{Display.repr(script, key)}: #{Display.repr(script, value)}"
    end)
    |> Enum.join(", ")
    |> then(fn set -> {script, "{#{set}}"} end)
  end
end
