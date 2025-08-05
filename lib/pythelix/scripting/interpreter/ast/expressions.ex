defmodule Pythelix.Scripting.Interpreter.AST.Expressions do
  @moduledoc """
  Handles expression AST nodes: operations, comparisons, logical operators.
  """

  alias Pythelix.Scripting.Interpreter.AST.Utils
  import Utils, only: [add: 2, replace: 3, length_code: 1]

  def read_ast(code, {op, [left, right]}) when op in [:+, :-, :*, :/] do
    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(left)
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(right)
    |> add({op, nil})
  end

  def read_ast(code, {cmp, [left, right]}) when cmp in [:<, :<=, :>, :>=, :==, :!=] do
    ref = make_ref()

    Enum.reduce([left, right], code, fn part, code ->
      case part do
        {cmp, [_left_part, right_part]} when cmp in [:<, :<=, :>, :>=, :==, :!=] ->
          code
          |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(part)
          |> add({:unset, ref})
          |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(right_part)

        _ ->
          code
          |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(part)
      end
    end)
    |> add({cmp, nil})
    |> replace({:unset, ref}, fn code -> {:iffalse, length_code(code)} end)
  end

  def read_ast(code, {cnt, [left, right]}) when cnt in [:in, :not_in] do
    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(left)
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(right)
    |> add({cnt, nil})
  end

  def read_ast(code, {:and, [left, right]}) do
    ref = make_ref()

    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(left)
    |> add({:unset, ref})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(right)
    |> replace({:unset, ref}, fn code -> {:iffalse, length_code(code)} end)
  end

  def read_ast(code, {:or, [left, right]}) do
    ref = make_ref()

    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(left)
    |> add({:unset, ref})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(right)
    |> replace({:unset, ref}, fn code -> {:iftrue, length_code(code)} end)
  end

  def read_ast(code, {:not, [ast]}) do
    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(ast)
    |> add({:not, nil})
  end

  def read_ast(code, {:getitem, [expr | items]}) do
    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(expr)
    |> then(fn code ->
      Enum.reduce(items, code, fn item, code ->
        code
        |> add({:getattr, "__getitem__"})
        |> add({:dict, :no_reference})
        |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(item)
        |> add({:call, 1})
      end)
    end)
  end

  def read_ast(code, seq) when is_list(seq) do
    Enum.reduce(seq, code, fn element, code ->
      Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, element)
    end)
    |> add({:list, length(seq)})
  end

  def read_ast(code, {:dict, elements}) do
    code =
      code
      |> add({:dict, nil})

    Enum.reduce(elements, code, fn {:element, [key, value]}, code ->
      code
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(value)
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(key)
      |> add({:put_dict, :last})
    end)
  end

  def read_ast(code, {:set, elements}) do
    code =
      code
      |> add({:set, nil})

    Enum.reduce(elements, code, fn {:element, [value]}, code ->
      code
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(value)
      |> add({:put_set, :last})
    end)
  end
end
