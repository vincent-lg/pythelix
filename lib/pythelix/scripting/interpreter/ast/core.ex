defmodule Pythelix.Scripting.Interpreter.AST.Core do
  @moduledoc """
  Core AST processing with delegation to specialized modules.
  """

  alias Pythelix.Scripting.Interpreter.AST.{Utils, Expressions, Statements, Assignments}
  import Utils, only: [add: 2, read_nested_ast: 2]

  def read_ast(code, {:var, var}) when is_binary(var) do
    code
    |> add({:read, var})
  end

  def read_ast(code, {:entity, key}) do
    code
    |> add({:builtin, "entity"})
    |> add({:dict, :no_reference})
    |> add({:put, key})
    |> add({:put_dict, {"key", :no_reference}})
    |> add({:call, 0})
  end

  def read_ast(code, {:function, name, args, kwargs}) do
    code =
      code
      |> add({:read, name})
      |> add({:dict, :no_reference})

    code =
      Enum.reduce(kwargs, code, fn {key, value}, code ->
        code
        |> read_ast(value)
        |> add({:put_dict, {key, :no_reference}})
      end)

    code
    |> Utils.read_asts(Enum.reverse(args))
    |> add({:call, length(args)})
  end

  def read_ast(code, [{:function, name, args, kwargs}, {:nested, sub}]) when is_list(sub) do
    code
    |> read_ast({:function, name, args, kwargs})
    |> read_nested_ast(sub)
  end

  def read_ast(code, [first, {:nested, sub}]) when is_list(sub) do
    code
    |> read_ast(first)
    |> read_nested_ast(sub)
  end

  def read_ast(code, {:time, h, m, s}) do
    alias Pythelix.Scripting.Object.Time
    code
    |> add({:put, %Time{hour: h, minute: m, second: s}})
  end

  def read_ast(code, {:duration, map}) when is_map(map) do
    alias Pythelix.Scripting.Object.Duration
    code
    |> add({:put, struct(Duration, map)})
  end

  def read_ast(code, global) when global in [true, false, :none] do
    code
    |> add({:put, global})
  end

  def read_ast(code, num) when is_number(num) do
    code
    |> add({:put, num})
  end

  def read_ast(code, str) when is_binary(str) do
    code
    |> add({:put, str})
  end

  def read_ast(code, {:formatted, str} = f_string) when is_binary(str) do
    code
    |> add({:put, f_string})
  end

  def read_ast(code, :line), do: code

  # Delegate to specialized modules
  def read_ast(code, {op, _} = ast) when op in [:+, :-, :*, :/, :**] do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, {cmp, _} = ast) when cmp in [:<, :<=, :>, :>=, :==, :!=] do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, {cnt, _} = ast) when cnt in [:in, :not_in] do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, {logical, _} = ast) when logical in [:and, :or, :not] do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, {:getitem, _} = ast) do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, seq) when is_list(seq) do
    Expressions.read_ast(code, seq)
  end

  def read_ast(code, {collection, _} = ast) when collection in [:dict, :set] do
    Expressions.read_ast(code, ast)
  end

  def read_ast(code, {:try, _, _, _, _, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:raise, _, _, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:if, _, _, _, _, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:while, _, _, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:for, _, _, _, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {stmt, _} = ast) when stmt in [:wait, :return] do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {stmt, _, _} = ast) when stmt in [:wait, :return, :raw] do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:raw, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:stmt_list, _} = ast) do
    Statements.read_ast(code, ast)
  end

  def read_ast(code, {:=, _, _, _} = ast) do
    Assignments.read_ast(code, ast)
  end

  def read_ast(code, {eq_op, _, _, _} = ast)
       when eq_op in [:"+=", :"-=", :"*=", :"/="] do
    Assignments.read_ast(code, ast)
  end

  def read_ast(_code, unknown) do
    raise "unknown AST portion: #{inspect(unknown)}"
  end
end
