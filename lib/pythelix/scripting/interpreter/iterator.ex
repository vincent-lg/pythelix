defmodule Pythelix.Scripting.Interpreter.Iterator do
  @moduledoc """
  Module describing the mutable iterator.
  """

  defstruct iterator: nil

  alias Pythelix.Scripting.Interpreter.Iterator
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Store

  def new(_script, enumerable) do
    enumerable = Store.get_value(enumerable)
    %Iterator{iterator: Enum.with_index(enumerable)}
  end

  @spec next(Script.t(), reference(), map()) :: {:count, Script.t(), term()} | :stop
  def next(script, reference, %Iterator{iterator: iterator}) do
    case Enum.at(iterator, 0) do
      nil ->
        :stop

      {element, index} ->
        script =
          script
          |> Script.write_variable("loop", index + 1)

        Store.update_reference(reference, %Iterator{iterator: Enum.drop(iterator, 1)})

        {:cont, script, element}
    end
  end
end
