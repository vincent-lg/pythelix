defmodule Pythelix.Scripting.Namespace.Dict do
  @moduledoc """
  Module defining the dict object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Object.Dict

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __getitem__(script, namespace), [
    {:item, index: 0, type: :any}
  ] do
    dict = Script.get_value(script, namespace.self, recursive: false)

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
    dict = Script.get_value(script, namespace.self, recursive: false)

    dict = Dict.put(dict, namespace.item, namespace.value)

    script = Script.update_reference(script, namespace.self, dict)

    {script, :none}
  end

  defmet clear(script, namespace), [] do
    dict = Dict.new()

    script =
      script
      |> Script.update_reference(namespace.self, dict)

    {script, :none}
  end

  defmet copy(script, namespace), [] do
    dict = Script.get_value(script, namespace.self)

    # Returning it will actually create a new reference, akin to a
    # deepcopy due to the nature of Elixir.
    {script, dict}
  end

  defmet get(script, namespace), [
    {:key, index: 0, type: :any},
    {:value, index: 1, type: :any, default: :none}
  ] do
    dict = Script.get_value(script, namespace.self, recursive: false)

    {script, Dict.get(dict, namespace.key, namespace.value)}
  end

  defmet items(script, namespace), [] do
    dict = Script.get_value(script, namespace.self)
    items =
      dict
      |> Dict.items()
      |> Enum.map(fn {key, value} -> [key, value] end)

    {script, items}
  end

  defmet keys(script, namespace), [] do
    dict = Script.get_value(script, namespace.self)
    {script, Dict.keys(dict)}
  end

  defmet pop(script, namespace), [
    {:key, index: 0, type: :any},
    {:default, index: 1, type: :any, default: :unset}
  ] do
    dict = Script.get_value(script, namespace.self)
    key = Script.get_value(script, namespace.key)

    case Dict.pop(dict, key, namespace.default) do
      {:unset, _} ->
        {Script.raise(script, KeyError, key), :none}

      {other, dict} ->
        script =
          script
          |> Script.update_reference(namespace.self, dict)

        {script, other}
    end
  end

  defmet popitem(script, namespace), [] do
    dict = Script.get_value(script, namespace.self)
    case Dict.popitem(dict) do
      :empty ->
        message = "popitem(): dictionary is empty"

        {Script.raise(script, KeyError, message), :none}

      {key, value, dict} ->
        script =
          script
          |> Script.update_reference(namespace.self, dict)

        {script, [key, value]}
    end
  end

  defmet setdefault(script, namespace), [
    {:key, index: 0, type: :any},
    {:default, index: 1, type: :any, default: :none}
  ] do
    dict = Script.get_value(script, namespace.self)
    key = Script.get_value(script, namespace.key)
    default = Script.get_value(script, namespace.default)

    case Dict.get(dict, key, :unset) do
      :unset ->
        dict = Dict.put(dict, key, default)

        script =
          script
          |> Script.update_reference(namespace.self, dict)

        {script, namespace.default}

      value ->
        {script, value}
    end
  end

  defmet update(script, namespace), [
    {:dict, index: 0, type: :dict, default: :none},
    {:kwargs, kwargs: true}
  ] do
    dict = Script.get_value(script, namespace.self)
    to_use = Script.get_value(script, namespace.dict)

    case to_use do
      :none ->
        dict =
          dict
          |> Dict.update(namespace.kwargs)

        Script.update_reference(script, namespace.self, dict)

      other ->
        dict =
          dict
          |> Dict.update(other)
          |> Dict.update(namespace.kwargs)

        Script.update_reference(script, namespace.self, dict)
    end
    |> then(& {&1, :none})
  end

  defmet values(script, namespace), [] do
    dict = Script.get_value(script, namespace.self)

    {script, Dict.values(dict)}
  end

  defp repr(script, self) do
    Script.get_value(script, self)
    |> Dict.items()
    |> IO.inspect(label: "dict")
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
