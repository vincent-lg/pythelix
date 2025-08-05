defmodule Pythelix.Scripting.Interpreter.AST.Utils do
  @moduledoc """
  Utility functions for AST processing.
  """

  def length_code(code) do
    :queue.len(code)
  end

  def add(code, value) do
    :queue.in(value, code)
  end

  def replace(code, what, by) do
    :queue.filtermap(
      fn bytecode ->
        case bytecode do
          ^what ->
            case by.(code) do
              false -> {true, {:noop, nil}}
              other -> {true, other}
            end

          _ ->
            true
        end
      end,
      code
    )
  end

  def read_asts(code, asts) do
    Enum.reduce(asts, code, fn ast, code ->
      Pythelix.Scripting.Interpreter.AST.Core.read_ast(code, ast)
    end)
  end

  def read_nested_ast(code, {:getitem, [{:var, to_get} | items]}) do
    code
    |> add({:getattr, to_get})
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

  def read_nested_ast(code, {:var, to_get}) when is_binary(to_get) do
    code
    |> add({:getattr, to_get})
  end

  def read_nested_ast(code, {:function, name, args, kwargs}) when is_binary(name) do
    code =
      code
      |> add({:getattr, name})
      |> add({:dict, :no_reference})

    code =
      Enum.reduce(kwargs, code, fn {key, value}, code ->
        code
        |> Pythelix.Scripting.Interpreter.AST.Core.read_ast(value)
        |> add({:put_dict, {key, :no_reference}})
      end)

    code
    |> read_asts(Enum.reverse(args))
    |> add({:call, length(args)})
  end

  def read_nested_ast(code, []) do
    code
  end

  def read_nested_ast(code, nested) when is_list(nested) do
    Enum.reduce(nested, code, fn nest, code -> read_nested_ast(code, nest) end)
  end

  def read_nested_ast(code, {:nested, nested}) do
    read_nested_ast(code, [nested])
  end
end
