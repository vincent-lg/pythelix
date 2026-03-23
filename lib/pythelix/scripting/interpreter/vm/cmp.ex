defmodule Pythelix.Scripting.Interpreter.VM.Cmp do
  @moduledoc """
  Grouping of comparison operations.
  """

  alias Pythelix.Scripting.Interpreter.Script

  @operations %{
    <: &</2,
    <=: &<=/2,
    >: &>/2,
    >=: &>=/2,
    ==: &==/2,
    !=: &!=/2
  }

  def lt(script, nil) do
    operation = @operations[:<]
    apply_op(script, operation)
  end

  def gt(script, nil) do
    operation = @operations[:>]
    apply_op(script, operation)
  end

  def le(script, nil) do
    operation = @operations[:<=]
    apply_op(script, operation)
  end

  def ge(script, nil) do
    operation = @operations[:>=]
    apply_op(script, operation)
  end

  def eq(script, nil) do
    operation = @operations[:==]
    apply_op(script, operation)
  end

  def ne(script, nil) do
    operation = @operations[:!=]
    apply_op(script, operation)
  end

  def is_op(script, nil) do
    apply_identity(script, &===/2)
  end

  def is_not_op(script, nil) do
    apply_identity(script, &!==/2)
  end

  defp apply_op(script, operation) do
    {script, value2} = Script.get_stack(script)
    {script, value1} = Script.get_stack(script)

    script
    |> Script.put_stack(operation.(value1, value2))
  end

  defp apply_identity(%{stack: [value2, value1 | rest]} = script, operation) do
    result = operation.(value1, value2)

    %{script | stack: rest}
    |> Script.put_stack(result)
  end
end
