defmodule Pythelix.ScriptingCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Pythelix.ScriptingCase
      import Pythelix.Scripting
      alias Pythelix.Scripting.Interpreter.{Debugger, Script}
      alias Pythelix.Scripting.Store
    end
  end

  setup tags do
    Pythelix.DataCase.setup_sandbox(tags)
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()
    :ok
  end

  @doc """
  Expect a properly parsed expression.

  This makes no assumption about AST, except that it provides a valid one.
  If it's not fully-parsed, it will fail.
  """
  @spec eval_ok(binary()) :: term()
  def eval_ok(code) do
    assert {:ok, ast} = Pythelix.Scripting.Parser.eval(code)

    ast
  end

  @doc """
  Test that a given expression fails.
  """
  @spec eval_fail(binary()) :: term()
  def eval_fail(code) do
    assert {:error, _} = Pythelix.Scripting.Parser.eval(code)
  end

  @doc """
  Expect a properly parsed script.

  This makes no assumption about AST, except that it provides a valid one.
  If it's not fully-parsed, it will fail.
  """
  @spec exec_ok(binary()) :: term()
  def exec_ok(code) do
    assert {:ok, ast} = Pythelix.Scripting.Parser.exec(code)

    ast
  end

  @doc """
  Test that a given code fails.
  """
  @spec exec_fail(binary()) :: term()
  def exec_fail(code) do
    assert {:error, _} = Pythelix.Scripting.Parser.exec(code)
  end

  @doc """
  Test to evaluate an expression and return it.
  """
  def expr_ok(code) do
    assert {:ok, value} = Pythelix.Scripting.eval(code)

    value
  end

  @doc """
  Make sure the evaluated code throws an exception.
  """
  def expr_fail(code) do
    assert {:error, traceback} = Pythelix.Scripting.eval(code)

    traceback
  end
end
