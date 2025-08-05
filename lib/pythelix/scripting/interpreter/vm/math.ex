defmodule Pythelix.Scripting.Interpreter.VM.Math do
  @moduledoc """
  Grouping of math operations.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Interpreter.VM.Math

  @operations %{
    +: &+/2,
    -: &-/2,
    *: &*/2,
    /: &//2,
    **: &Math.over_pow/2
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

  def pow(script, nil) do
    operation = @operations[:**]
    apply_op(script, operation)
  end

  defp apply_op(script, operation) do
    {script, value2} = Script.get_stack(script)
    {script, value1} = Script.get_stack(script)

    script
    |> Script.put_stack(operation.(value1, value2))
  end

  def over_pow(number, power) do
    result = :math.pow(number, power)

    if result == trunc(result) do
      trunc(result)
    else
      result
    end
  end
end
