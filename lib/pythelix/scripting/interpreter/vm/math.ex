defmodule Pythelix.Scripting.Interpreter.VM.Math do
  @moduledoc """
  Grouping of math operations.
  """

  alias Pythelix.Scripting.Interpreter.Script

  @operations %{
    +: &+/2,
    -: &-/2,
    *: &*/2,
    /: &//2
  }

  def add(script, nil) do
    operation = @operations[:+]
    apply_op(script, operation)
  end

  def sub(script, nil) do
    operation = @operations[:-]
    apply_op(script, operation)
  end

  def mul(script, nil) do
    operation = @operations[:*]
    apply_op(script, operation)
  end

  def div(script, nil) do
    operation = @operations[:/]
    apply_op(script, operation)
  end

  defp apply_op(script, operation) do
    {script, value2} = Script.get_stack(script)
    {script, value1} = Script.get_stack(script)

    script
    |> Script.put_stack(operation.(value1, value2))
  end
end
