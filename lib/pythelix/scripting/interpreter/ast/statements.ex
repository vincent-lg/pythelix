defmodule Pythelix.Scripting.Interpreter.AST.Statements do
  @moduledoc """
  Handles statement AST nodes: control flow structures.
  """

  alias Pythelix.Scripting.Interpreter.AST.Utils
  alias Pythelix.Scripting.Interpreter.AST
  import Utils, only: [add: 2, replace: 3, length_code: 1, read_asts: 2]

  def read_ast(code, {:try, try_body, except_clauses, else_block, finally_block, {line, _}}) do
    except_start = make_ref()
    else_target = make_ref()
    finally_target = make_ref()

    # setup_try -> EXCEPT_START; try body; pop_try; goto -> ELSE_START
    code =
      code
      |> add({:line, line})
      |> add({:unset, except_start})
      |> read_asts(try_body)
      |> add({:pop_try, nil})
      |> add({:unset, else_target})
      |> replace({:unset, except_start}, fn code -> {:setup_try, length_code(code)} end)

    # Except clauses: check_exc + body + goto -> FINALLY_START
    code =
      Enum.reduce(except_clauses, code, fn {exc_name, body}, code ->
        next_except = make_ref()
        exc_atom = if exc_name, do: Module.concat([String.to_atom(exc_name)]), else: nil

        code
        |> add({:unset, next_except})
        |> read_asts(body)
        |> add({:unset, finally_target})
        |> replace({:unset, next_except}, fn code -> {:check_exc, {exc_atom, length_code(code)}} end)
      end)

    # Reraise if no handler matched
    code = code |> add({:reraise, nil})

    # Resolve else_target -> here (after except blocks)
    code = replace(code, {:unset, else_target}, fn code -> {:goto, length_code(code)} end)

    # Else block (only runs if no exception)
    code =
      case else_block do
        nil -> code
        _ -> read_asts(code, else_block)
      end

    # Resolve finally_target -> here (after else block)
    code = replace(code, {:unset, finally_target}, fn code -> {:goto, length_code(code)} end)

    # Finally block (always runs)
    code =
      case finally_block do
        nil -> code
        _ -> read_asts(code, finally_block)
      end

    code |> add({:end_try, nil})
  end

  def read_ast(code, {:raise, exc_name, args, {line, _}}) do
    exc_atom = Module.concat([String.to_atom(exc_name)])

    code = code |> add({:line, line})

    code =
      case args do
        [msg_expr] -> AST.Core.read_ast(code, msg_expr)
        [] -> code |> add({:put, :none})
      end

    code |> add({:raise, exc_atom})
  end

  def read_ast(code, {:if, condition, then, [], nil, {line, _}}) do
    end_block = make_ref()

    code
    |> add({:line, line})
    |> AST.Core.read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(then)
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  def read_ast(code, {:if, condition, then, [], otherwise, {line, _}}) do
    else_block = make_ref()
    end_block = make_ref()

    code
    |> add({:line, line})
    |> AST.Core.read_ast(condition)
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
    |> AST.Core.read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(block)
    |> add({:goto, before})
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  def read_ast(code, {:for, variable, iterate, block, {line, _}}) do
    code =
      code
      |> add({:line, line})
      |> AST.Core.read_ast(iterate)
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
        AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:wait, nil})
  end

  def read_ast(code, {:wait, values}) when is_list(values) do
    code
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:wait, nil})
  end

  def read_ast(code, {:return, [{_, {line, _}} | values]}) do
    code
    |> add({:line, line})
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:return, nil})
  end

  def read_ast(code, {:return, values}) when is_list(values) do
    code
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code ->
        AST.Core.read_ast(code, value)
      end)
    end)
    |> add({:return, nil})
  end

  def read_ast(code, {:raw, expr, {line, _}}) do
    code
    |> add({:line, line})
    |> AST.Core.read_ast(expr)
    |> add({:raw, nil})
  end

  def read_ast(code, {:raw, expr}) do
    code
    |> AST.Core.read_ast(expr)
    |> add({:raw, nil})
  end

  def read_ast(code, {:stmt_list, statements}) when is_list(statements) do
    Enum.reduce(statements, code, fn statement, code ->
      AST.Core.read_ast(code, statement)
    end)
  end

  defp compile_if_elif_chain(code, condition, then, elifs, otherwise) do
    next_block = make_ref()
    end_block = make_ref()

    code =
      code
      |> AST.Core.read_ast(condition)
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
      |> AST.Core.read_ast(condition)
      |> add({:unset, next_block})
      |> read_asts(then)
      |> add({:unset, end_block})
      |> replace({:unset, next_block}, fn code -> {:popiffalse, length_code(code)} end)

    compile_elifs(code, rest, end_block)
  end
end
