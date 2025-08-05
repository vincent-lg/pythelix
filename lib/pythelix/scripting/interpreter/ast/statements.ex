defmodule Pythelix.Scripting.Interpreter.AST.Statements do
  @moduledoc """
  Handles statement AST nodes: control flow structures.
  """

  alias Pythelix.Scripting.Interpreter.AST.Utils
  import Utils, only: [add: 2, replace: 3, length_code: 1, read_asts: 2]

  def read_ast(code, {:if, condition, then, [], nil, {line, _}}) do
    end_block = make_ref()

    code
    |> add({:line, line})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(then)
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  def read_ast(code, {:if, condition, then, [], otherwise, {line, _}}) do
    else_block = make_ref()
    end_block = make_ref()

    code
    |> add({:line, line})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(condition)
    |> add({:unset, else_block})
    |> read_asts(then)
    |> add({:unset, end_block})
    |> replace({:unset, else_block}, fn code -> {:popiffalse, length_code(code)} end)
    |> read_asts(otherwise)
    |> replace({:unset, end_block}, fn code -> {:goto, length_code(code)} end)
  end

  def read_ast(code, {:if, condition, then, elifs, otherwise, {line, _}}) do
    code
    |> add({:line, line})
    |> compile_if_elif_chain(condition, then, elifs, otherwise)
  end

  def read_ast(code, {:while, condition, block, {line, _}}) do
    before = length_code(code)
    end_block = make_ref()

    code
    |> add({:line, line})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(block)
    |> add({:goto, before})
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  def read_ast(code, {:for, variable, iterate, block, {line, _}}) do
    code =
      code
      |> add({:line, line})
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(iterate)
      |> add({:mkiter, nil})

    before = length_code(code)
    end_block = make_ref()

    code
    |> add({:unset, end_block})
    |> add({:store, variable})
    |> read_asts(block)
    |> add({:goto, before})
    |> replace({:unset, end_block}, fn code -> {:iter, length_code(code)} end)
  end

  def read_ast(code, {:wait, [{_, {line, _}} | values]}) do
    code
    |> add({:line, line})
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:wait, nil})
  end

  def read_ast(code, {:wait, values}) when is_list(values) do
    code
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:wait, nil})
  end

  def read_ast(code, {:return, [{_, {line, _}} | values]}) do
    code
    |> add({:line, line})
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:return, nil})
  end

  def read_ast(code, {:return, values}) when is_list(values) do
    code
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:return, nil})
  end

  def read_ast(code, {:raw, expr, {line, _}}) do
    code
    |> add({:line, line})
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(expr)
    |> add({:raw, nil})
  end

  def read_ast(code, {:raw, expr}) do
    code
    |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(expr)
    |> add({:raw, nil})
  end

  def read_ast(code, {:stmt_list, statements}) when is_list(statements) do
    Enum.reduce(statements, code, fn statement, code ->
      Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, statement)
    end)
  end

  defp compile_if_elif_chain(code, condition, then, elifs, otherwise) do
    next_block = make_ref()
    end_block = make_ref()

    code =
      code
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(condition)
      |> add({:unset, next_block})
      |> read_asts(then)
      |> add({:unset, end_block})
      |> replace({:unset, next_block}, fn code -> {:popiffalse, length_code(code)} end)

    code = compile_elifs(code, elifs, end_block)

    code =
      case otherwise do
        nil -> code
        _ -> read_asts(code, otherwise)
      end

    replace(code, {:unset, end_block}, fn code -> {:goto, length_code(code)} end)
  end

  defp compile_elifs(code, [], _end_block), do: code

  defp compile_elifs(code, [{condition, then} | rest], end_block) do
    next_block = make_ref()

    code =
      code
      |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(condition)
      |> add({:unset, next_block})
      |> read_asts(then)
      |> add({:unset, end_block})
      |> replace({:unset, next_block}, fn code -> {:popiffalse, length_code(code)} end)

    compile_elifs(code, rest, end_block)
  end
end
