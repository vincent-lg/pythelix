defmodule Pythelix.Scripting.Interpreter.AST.Assignments do
  @moduledoc """
  Handles assignment AST nodes: simple and compound assignments.
  """

  alias Pythelix.Scripting.Interpreter.AST.Utils
  alias Pythelix.Scripting.Interpreter.AST
  import Utils, only: [add: 2, replace: 3, length_code: 1]

  @eq_op %{"+=": :+, "-=": :-, "*=": :*, "/=": :/}

  def read_ast(code, {:=, names, value, {line, _}}) do
    before = make_ref()
    after_ref = make_ref()
    after_pos = length_code(code) + 2

    code =
      code
      |> add({:line, line})
      |> add({:unset, before})
      |> AST.Core.read_ast(value)
      |> add({:unset, after_ref})

    end_pos = length_code(code)

    Enum.reduce(Enum.with_index(names), code, fn
      {[{:getitem, [expr | items]}], index}, code when index == length(names) - 1 ->
        Enum.reduce(Enum.with_index(items), AST.Core.read_ast(code, expr), fn
          {item, i_index}, code when length(items) - 1 == i_index and length(names) - 1 == index ->
            code
            |> add({:getattr, "__setitem__"})
            |> add({:dict, :no_reference})
            |> AST.Core.read_ast(item)
            |> add({:goto, after_pos})
            |> replace({:unset, before}, fn _code -> {:goto, end_pos} end)
            |> replace({:unset, after_ref}, fn code -> {:goto, length_code(code)} end)
            |> add({:call, 2})

          {item, _}, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> AST.Core.read_ast(item)
            |> add({:call, 1})
        end)

      {[{:getitem, [expr | items]}], _}, code ->
        Enum.reduce(items, AST.Core.read_ast(code, expr), fn item, code ->
          code
          |> add({:getattr, "__getitem__"})
          |> add({:dict, :no_reference})
          |> AST.Core.read_ast(item)
          |> add({:call, 1})
        end)

      {name, 0}, code when length(names) == 1 ->
        code
        |> add({:store, name})

      {name, 0}, code ->
        code
        |> add({:read, name})

      {name, index}, code when index == length(names) - 1 ->
        add(code, {:setattr, name})

      {name, _}, code ->
        add(code, {:getattr, name})
    end)
    |> replace({:unset, before}, fn _code -> false end)
    |> replace({:unset, after_ref}, fn _code -> false end)
  end

  def read_ast(code, {eq_op, names, value, {line, _}})
       when eq_op in [:"+=", :"-=", :"*=", :"/="] do
    op = Map.get(@eq_op, eq_op)

    before = make_ref()
    before_pos = length_code(code) + 1
    after_pos = before_pos + 1
    after_ref = make_ref()

    code =
      code
      |> add({:line, line})
      |> add({:unset, before})

    code =
      Enum.reduce(Enum.with_index(names), code, fn
        {[{:getitem, [expr | items]}], _}, code ->
          Enum.reduce(items, AST.Core.read_ast(code, expr), fn item, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> AST.Core.read_ast(item)
            |> add({:call, 1})
          end)

        {name, 0}, code ->
          add(code, {:read, name})

        {name, _}, code ->
          add(code, {:getattr, name})
      end)

    code =
      code
      |> AST.Core.read_ast(value)
      |> add({op, nil})
      |> add({:unset, after_ref})

    end_pos = length_code(code)

    Enum.reduce(Enum.with_index(names), code, fn
      {[{:getitem, [expr | items]}], index}, code when index == length(names) - 1 ->
        Enum.reduce(Enum.with_index(items), AST.Core.read_ast(code, expr), fn
          {item, i_index}, code when length(items) - 1 == i_index and length(names) - 1 == index ->
            code
            |> add({:getattr, "__setitem__"})
            |> add({:dict, :no_reference})
            |> AST.Core.read_ast(item)
            |> add({:goto, after_pos})
            |> replace({:unset, before}, fn _code -> {:goto, end_pos} end)
            |> replace({:unset, after_ref}, fn code -> {:goto, length_code(code)} end)
            |> add({:call, 2})

          {item, _}, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> AST.Core.read_ast(item)
            |> add({:call, 1})
        end)

      {[{:getitem, [expr | items]}], _}, code ->
        Enum.reduce(items, AST.Core.read_ast(code, expr), fn item, code ->
          code
          |> add({:getattr, "__getitem__"})
          |> add({:dict, :no_reference})
          |> AST.Core.read_ast(item)
          |> add({:call, 1})
        end)

      {name, 0}, code when length(names) == 1 ->
        add(code, {:store, name})

      {name, 0}, code ->
        add(code, {:read, name})

      {name, index}, code when index == length(names) - 1 ->
        add(code, {:setattr, name})

      {name, _}, code ->
        add(code, {:getattr, name})
    end)
    |> replace({:unset, before}, fn _code -> false end)
    |> replace({:unset, after_ref}, fn _code -> false end)
  end
end
