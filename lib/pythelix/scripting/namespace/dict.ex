defmodule Pythelix.Scripting.Namespace.Dict do
  @moduledoc """
  Module defining the dict object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.Dict

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
    dict = Script.get_value(script, namespace.self)
    key = Script.get_value(script, namespace.key)


    {script, Dict.get(dict, key, namespace.value)}
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
end
