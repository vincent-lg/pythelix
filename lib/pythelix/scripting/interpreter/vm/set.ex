defmodule Pythelix.Scripting.Interpreter.VM.Set do
  @moduledoc """
  Grouping of set operations.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Store

  def put(script, :last) do
    {script, {value, valueref}} = Script.get_stack(script, :reference)
    {script, {set, ref}} = Script.get_stack(script, :reference)

    set = MapSet.put(set, valueref || value)
    Store.update_reference(ref, set)

    script
    |> Script.put_stack(ref)
  end

  def new(script, nil) do
    script
    |> Script.put_stack(MapSet.new())
  end
end
