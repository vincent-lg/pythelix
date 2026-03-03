defmodule Pythelix.Scripting.Interpreter.VM.Math do
  @moduledoc """
  Grouping of math operations.
  """

  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Interpreter.VM.Math
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Scripting.Store

  @operations %{
    +: &+/2,
    -: &-/2,
    *: &*/2,
    /: &//2,
    **: &Math.over_pow/2
  }

  @magic_methods %{
    +: "__add__",
    -: "__sub__",
    *: "__mul__",
    /: "__div__"
  }

  def add(script, nil) do
    apply_op(script, :+)
  end

  def sub(script, nil) do
    apply_op(script, :-)
  end

  def mul(script, nil) do
    apply_op(script, :*)
  end

  def div(script, nil) do
    apply_op(script, :/)
  end

  def pow(script, nil) do
    apply_op(script, :**)
  end

  defp apply_op(script, op) do
    {script, value2} = Script.get_stack(script)
    {script, value1} = Script.get_stack(script)

    if is_number(value1) and is_number(value2) do
      operation = @operations[op]
      script |> Script.put_stack(operation.(value1, value2))
    else
      call_magic_method(script, op, value1, value2)
    end
  end

  defp call_magic_method(script, op, value1, value2) do
    case @magic_methods[op] do
      nil ->
        Script.raise(script, TypeError, "unsupported operand type(s) for #{op}")

      method_name ->
        # For mixed types (e.g. 3 * "o"), call the magic method on the non-number.
        # For two non-numbers, call on value1 (left operand, matching Python).
        {self, other} =
          if is_number(value1) and not is_number(value2) do
            {value2, value1}
          else
            {value1, value2}
          end

        resolved = Store.get_value(self, recursive: false)
        module = Namespace.locate(resolved)
        name = String.to_atom("m_#{method_name}")

        if function_exported?(module, name, 4) do
          callable = %Callable{module: module, object: self, name: name}

          case Callable.call(script, callable, [other]) do
            {%Script{error: error} = script, _} when error != nil ->
              script

            {script, value} ->
              Script.put_stack(script, Store.get_value(value))
          end
        else
          Script.raise(script, TypeError, "unsupported operand type(s) for #{op}")
        end
    end
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
