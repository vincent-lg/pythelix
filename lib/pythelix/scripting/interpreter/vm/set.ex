defmodule Pythelix.Scripting.Interpreter.VM.Set do
  @moduledoc """
  Grouping of set operations.
  """

  alias Pythelix.Scripting.Interpreter.Script

  def put(script, :last) do
    {script, {value, valueref}} = Script.get_stack(script, :reference)
    {script, {set, ref}} = Script.get_stack(script, :reference)

    set = MapSet.put(set, valueref || value)

    script
    |> Script.update_reference(ref, set)
    |> Script.put_stack(ref)
  end

  def new(script, nil) do
    script
    |> Script.put_stack(MapSet.new())
  end
end
