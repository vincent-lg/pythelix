defmodule Pythelix.Scripting.Interpreter.AST do
  @moduledoc """
  A module to convert an Abstract-Syntax Tree (AST) into a script structure.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Store

  @eq_op %{"+=": :+, "-=": :-, "*=": :*, "/=": :/}

  @doc """
  Convert an AST into a script structure with its bytecode.
  """
  @spec convert(list()) :: Script.t()
  def convert(ast, opts \\ []) do
    bytecode =
      ast
      |> Enum.reduce(:queue.new(), &process_ast/2)
      |> :queue.to_list()

    %Script{id: (opts[:id] || Store.new_script()), bytecode: bytecode}
  end

  defp process_ast(ast, code) do
    read_ast(code, ast)
  end

  defp read_ast(code, {:var, var}) when is_binary(var) do
    code
    |> add({:read, var})
  end

  defp read_ast(code, {:entity, key}) do
    code
    |> add({:builtin, "entity"})
    |> add({:dict, :no_reference})
    |> add({:put, key})
    |> add({:put_dict, {"key", :no_reference}})
    |> add({:call, 0})
  end

  defp read_ast(code, {:function, name, args, kwargs}) do
    code =
      code
      #|> add({:builtin, name})
      |> add({:read, name})
      |> add({:dict, :no_reference})

    code =
      Enum.reduce(kwargs, code, fn {key, value}, code ->
        code
        |> read_ast(value)
        |> add({:put_dict, {key, :no_reference}})
      end)

    code
    |> read_asts(Enum.reverse(args))
    |> add({:call, length(args)})
  end

  defp read_ast(code, {:getitem, [expr | items]}) do
    code
    |> read_ast(expr)
    |> then(fn code ->
      Enum.reduce(items, code, fn item, code ->
        code
        |> add({:getattr, "__getitem__"})
        |> add({:dict, :no_reference})
        |> read_ast(item)
        |> add({:call, 1})
      end)
    end)
  end

  defp read_ast(code, [{:function, name, args, kwargs}, {:nested, sub}]) when is_list(sub) do
    code
    |> read_ast({:function, name, args, kwargs})
    |> read_nested_ast(sub)
  end

  defp read_ast(code, [first, {:nested, sub}]) when is_list(sub) do
    code
    |> read_ast(first)
    |> read_nested_ast(sub)
  end

  defp read_ast(code, global) when global in [true, false, :none] do
    code
    |> add({:put, global})
  end

  defp read_ast(code, num) when is_number(num) do
    code
    |> add({:put, num})
  end

  defp read_ast(code, str) when is_binary(str) do
    code
    |> add({:put, str})
  end

  defp read_ast(code, {:formatted, str} = f_string) when is_binary(str) do
    code
    |> add({:put, f_string})
  end

  defp read_ast(code, seq) when is_list(seq) do
    Enum.reduce(seq, code, fn element, code -> read_ast(code, element) end)
    |> add({:list, length(seq)})
  end

  defp read_ast(code, {:dict, elements}) do
    code =
      code
      |> add({:dict, nil})

    Enum.reduce(elements, code, fn {:element, [key, value]}, code ->
      code
      |> read_ast(value)
      |> read_ast(key)
      |> add({:put_dict, :last})
    end)
  end

  defp read_ast(code, {:set, elements}) do
    code =
      code
      |> add({:set, nil})

    Enum.reduce(elements, code, fn {:element, [value]}, code ->
      code
      |> read_ast(value)
      |> add({:put_set, :last})
    end)
  end

  defp read_ast(code, {op, [left, right]}) when op in [:+, :-, :*, :/] do
    code
    |> read_ast(left)
    |> read_ast(right)
    |> add({op, nil})
  end

  defp read_ast(code, {cmp, [left, right]}) when cmp in [:<, :<=, :>, :>=, :==, :!=] do
    ref = make_ref()

    Enum.reduce([left, right], code, fn part, code ->
      case part do
        {cmp, [_left_part, right_part]} when cmp in [:<, :<=, :>, :>=, :==, :!=] ->
          code
          |> read_ast(part)
          |> add({:unset, ref})
          |> read_ast(right_part)

        _ ->
          code
          |> read_ast(part)
      end
    end)
    |> add({cmp, nil})
    |> replace({:unset, ref}, fn code -> {:iffalse, length_code(code)} end)
  end

  defp read_ast(code, {cnt, [left, right]}) when cnt in [:in, :not_in] do
    code
    |> read_ast(left)
    |> read_ast(right)
    |> add({cnt, nil})
  end

  defp read_ast(code, {:and, [left, right]}) do
    ref = make_ref()

    code
    |> read_ast(left)
    |> add({:unset, ref})
    |> read_ast(right)
    |> replace({:unset, ref}, fn code -> {:iffalse, length_code(code)} end)
  end

  defp read_ast(code, {:or, [left, right]}) do
    ref = make_ref()

    code
    |> read_ast(left)
    |> add({:unset, ref})
    |> read_ast(right)
    |> replace({:unset, ref}, fn code -> {:iftrue, length_code(code)} end)
  end

  defp read_ast(code, {:not, [ast]}) do
    code
    |> read_ast(ast)
    |> add({:not, nil})
  end

  defp read_ast(code, {:stmt_list, statements}) when is_list(statements) do
    Enum.reduce(statements, code, fn statement, code ->
      read_ast(code, statement)
    end)
  end

  defp read_ast(code, {:=, names, value, {line, _}}) do
    before = make_ref()
    after_ref = make_ref()
    after_pos = length_code(code) + 2

    code =
      code
      |> add({:line, line})
      |> add({:unset, before})
      |> read_ast(value)
      |> add({:unset, after_ref})

    end_pos = length_code(code)

    Enum.reduce(Enum.with_index(names), code, fn
      {[{:getitem, [expr | items]}], index}, code when index == length(names) - 1 ->
        Enum.reduce(Enum.with_index(items), read_ast(code, expr), fn
          {item, i_index}, code when length(items) - 1 == i_index and length(names) - 1 == index ->
            code
            |> add({:getattr, "__setitem__"})
            |> add({:dict, :no_reference})
            |> read_ast(item)
            |> add({:goto, after_pos})
            |> replace({:unset, before}, fn _code -> {:goto, end_pos} end)
            |> replace({:unset, after_ref}, fn code -> {:goto, length_code(code)} end)
            |> add({:call, 2})

          {item, _}, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> read_ast(item)
            |> add({:call, 1})
        end)

      {[{:getitem, [_expr | items]}], _}, code ->
        Enum.reduce(items, code, fn item, code ->
          code
          |> add({:getattr, "__getitem__"})
          |> add({:dict, :no_reference})
          |> read_ast(item)
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

  defp read_ast(code, {eq_op, names, value, {line, _}})
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
          Enum.reduce(items, read_ast(code, expr), fn item, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> read_ast(item)
            |> add({:call, 1})
          end)

        {name, 0}, code ->
          add(code, {:read, name})

        {name, _}, code ->
          add(code, {:getattr, name})
      end)

    code =
      code
      |> read_ast(value)
      |> add({op, nil})
      |> add({:unset, after_ref})

    end_pos = length_code(code)

    Enum.reduce(Enum.with_index(names), code, fn
      {[{:getitem, [expr | items]}], index}, code when index == length(names) - 1 ->
        Enum.reduce(Enum.with_index(items), read_ast(code, expr), fn
          {item, i_index}, code when length(items) - 1 == i_index and length(names) - 1 == index ->
            code
            |> add({:getattr, "__setitem__"})
            |> add({:dict, :no_reference})
            |> read_ast(item)
            |> add({:goto, after_pos})
            |> replace({:unset, before}, fn _code -> {:goto, end_pos} end)
            |> replace({:unset, after_ref}, fn code -> {:goto, length_code(code)} end)
            |> add({:call, 2})

          {item, _}, code ->
            code
            |> add({:getattr, "__getitem__"})
            |> add({:dict, :no_reference})
            |> read_ast(item)
            |> add({:call, 1})
        end)

      {[{:getitem, [_expr | items]}], _}, code ->
        Enum.reduce(items, code, fn item, code ->
          code
          |> add({:getattr, "__getitem__"})
          |> add({:dict, :no_reference})
          |> read_ast(item)
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

  defp read_ast(code, {:if, condition, then, nil, {line, _}}) do
    end_block = make_ref()

    code
    |> add({:line, line})
    |> read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(then)
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  defp read_ast(code, {:if, condition, then, otherwise, {line, _}}) do
    else_block = make_ref()
    end_block = make_ref()

    code
    |> add({:line, line})
    |> read_ast(condition)
    |> add({:unset, else_block})
    |> read_asts(then)
    |> add({:unset, end_block})
    |> replace({:unset, else_block}, fn code -> {:popiffalse, length_code(code)} end)
    |> read_asts(otherwise)
    |> replace({:unset, end_block}, fn code -> {:goto, length_code(code)} end)
  end

  defp read_ast(code, {:while, condition, block, {line, _}}) do
    before = length_code(code)
    end_block = make_ref()

    code
    |> add({:line, line})
    |> read_ast(condition)
    |> add({:unset, end_block})
    |> read_asts(block)
    |> add({:goto, before})
    |> replace({:unset, end_block}, fn code -> {:popiffalse, length_code(code)} end)
  end

  defp read_ast(code, {:for, variable, iterate, block, {line, _}}) do
    code =
      code
      |> add({:line, line})
      |> read_ast(iterate)
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

  defp read_ast(code, {:wait, [{_, {line, _}} | values]}) do
    code
    |> add({:line, line})
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code -> read_ast(code, value) end)
    end)
    |> add({:wait, nil})
  end

  defp read_ast(code, {:return, [{_, {line, _}} | values]}) do
    code
    |> add({:line, line})
    |> then(fn code ->
      Enum.reduce(values, code, fn value, code -> read_ast(code, value) end)
    end)
    |> add({:return, nil})
  end

  defp read_ast(code, {:raw, expr, {line, _}}) do
    code
    |> add({:line, line})
    |> read_ast(expr)
    |> add({:raw, nil})
  end

  defp read_ast(code, :line), do: code

  defp read_ast(_code, unknown) do
    raise "unknown AST portion: #{inspect(unknown)}"
  end

  def read_asts(code, asts) do
    Enum.reduce(asts, code, fn ast, code -> read_ast(code, ast) end)
  end

  defp read_nested_ast(code, {:getitem, [{:var, to_get} | items]}) do
    code
    |> add({:getattr, to_get})
    |> then(fn code ->
      Enum.reduce(items, code, fn item, code ->
        code
        |> add({:getattr, "__getitem__"})
        |> add({:dict, :no_reference})
        |> read_ast(item)
        |> add({:call, 1})
      end)
    end)
  end

  defp read_nested_ast(code, {:var, to_get}) when is_binary(to_get) do
    code
    |> add({:getattr, to_get})
  end

  defp read_nested_ast(code, {:function, name, args, kwargs}) when is_binary(name) do
    code =
      code
      |> add({:getattr, name})
      |> add({:dict, :no_reference})

    code =
      Enum.reduce(kwargs, code, fn {key, value}, code ->
        code
        |> read_ast(value)
        |> add({:put_dict, {key, :no_reference}})
      end)

    code
    |> read_asts(Enum.reverse(args))
    |> add({:call, length(args)})
  end

  defp read_nested_ast(code, []) do
    code
  end

  defp read_nested_ast(code, nested) when is_list(nested) do
    Enum.reduce(nested, code, fn nest, code -> read_nested_ast(code, nest) end)
  end

  defp read_nested_ast(code, {:nested, nested}) do
    read_nested_ast(code, [nested])
  end

  defp length_code(code) do
    :queue.len(code)
  end

  defp add(code, value) do
    :queue.in(value, code)
  end

  defp replace(code, what, by) do
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
end
