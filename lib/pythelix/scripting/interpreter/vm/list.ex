defmodule Pythelix.Scripting.Interpreter.VM.List do
  @moduledoc """
  Grouping of list operations.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Namespace

  def new(script, len) do
    {script, values} =
      if len > 0 do
        Enum.reduce(1..len, {script, []}, fn _, {script, values} ->
          {script, {value, reference}} = Script.get_stack(script, :reference)

          case reference do
            nil -> {script, [value | values]}
            _ -> {script, [reference | values]}
          end
        end)
      else
        {script, []}
      end

    script
    |> Script.put_stack(values)
  end

  def in_(script, nil) do
    {script, {collection, ref}} = Script.get_stack(script, :reference)
    {script, {_, element}} = Script.get_stack(script, :reference)
    namespace = Namespace.locate(collection)
     {script, value} = Namespace.call(namespace, "__contains__", script, collection, ref, [element])

    script
    |> Script.put_stack(value)
  end

  def not_in(script, nil) do
    {script, {collection, ref}} = Script.get_stack(script, :reference)
    {script, {_, element}} = Script.get_stack(script, :reference)
    namespace = Namespace.locate(collection)
     {script, value} = Namespace.call(namespace, "__contains__", script, collection, ref, [element])

    script
    |> Script.put_stack(!value)
  end
end
