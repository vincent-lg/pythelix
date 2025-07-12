defmodule Pythelix.Scripting.Interpreter.VM.Dict do
  @moduledoc """
  Grouping of dictionary operations.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object
  alias Pythelix.Scripting.Store

  def put(script, :last) do
    {script, {key, keyref}} = Script.get_stack(script, :reference)
    {script, {value, valueref}} = Script.get_stack(script, :reference)
    {script, {dict, ref}} = Script.get_stack(script, :reference)

    dict = Object.Dict.put(dict, keyref || key, valueref || value)
    Store.update_reference(ref, dict)

    script
    |> Script.put_stack(ref)
  end

  def put(script, {key, :no_reference}) do
    {script, to_put} = Script.get_stack(script)
    {script, dict} = Script.get_stack(script)

    dict = Object.Dict.put(dict, key, to_put)

    script
    |> Script.put_stack(dict, :no_reference)
  end

  def new(script, nil) do
    script
    |> Script.put_stack(Object.Dict.new())
  end

  def new(script, :no_reference) do
    script
    |> Script.put_stack(Object.Dict.new(), :no_reference)
  end
end
