defmodule Pythelix.Scripting.Namespace.Module.Code do
  @moduledoc """
  Module defining the code module for Pythello scripting.

  Provides the Console class for interactive code evaluation.
  """

  use Pythelix.Scripting.Module, name: "code"

  alias Pythelix.Scripting.Object.{Console, Dict}

  @doc """
  Create a new Console, optionally with initial variables.

  Usage in Pythello:

      console = code.Console()
      console = code.Console({"self": some_entity, "location": room})
  """
  deffun function_Console(script, namespace), [
    {:variables, index: 0, type: :dict, default: :none}
  ] do
    variables =
      case namespace.variables do
        :none ->
          %{}

        ref ->
          Store.get_value(ref)
          |> Dict.items()
          |> Enum.map(fn {key, value} -> {key, Store.get_value(value)} end)
          |> Map.new()
      end

    console = %Console{variables: variables}
    {script, ref} = Script.reference(script, console)
    {script, ref}
  end
end
