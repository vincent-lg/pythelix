defmodule Pythelix.Scripting.Parser.Statement do
  @moduledoc """
  Parser to parse a statement.

  Grammar:
    <nested> ::= "(" <expr> ")" | <value>
    <expr>  ::= <term0> {"+" | "-" <term0>}
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Constants, only: [id: 0, isolate: 1, isolate: 2]
  import Pythelix.Scripting.Parser.Operator

  newline = string("\n") |> replace(:line) |> label("newline") |> isolate(check: false)

  equal = string("=") |> label("=") |> replace(:=) |> isolate(check: false)
  colon = ascii_char([?:]) |> label(":") |> replace(:":") |> isolate(check: false)
  if_kw = string("if") |> label("if") |> replace(:if) |> isolate(space: true)
  elif_kw = string("elif") |> label("elif") |> replace(:elif) |> isolate(space: true)
  else_kw = string("else") |> label("else") |> replace(:else) |> isolate()
  while_kw = string("while") |> label("while") |> replace(:while) |> isolate(space: true)
  endif = string("endif") |> label("endif") |> replace(:endif) |> isolate()
  done = string("done") |> label("done") |> replace(:done) |> isolate()
  for_kw = string("for") |> label("for") |> replace(:for) |> isolate(space: true)
  in_kw = string("in") |> label("in") |> replace(:in) |> isolate(space: true)
  wait_kw = string("wait") |> label("wait") |> replace(:wait) |> isolate(space: true)
  return_kw = string("return") |> label("return") |> replace(:return) |> isolate(space: true)

  setitem =
    parsec({Pythelix.Scripting.Parser.Value, :getitem})
    |> tag(:setitem)

  assignment =
    choice([setitem, id()])
    |> repeat(
      ignore(dot())
      |> choice([setitem, id()])
    )
    |> tag(:nested)
    |> line()
    |> concat(
      choice([equal, plus_eq(), minus_eq(), mul_eq(), div_eq()])
      |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    )
    |> reduce(:reduce_assign)
    |> label("assignment")

  defp reduce_assign([{[{:nested, nested}], {line, offset}}, opeq, value]) do
    names = for {_, name} <- nested, do: name
    {opeq, names, value, {line, offset}}
  end

  elif_branch =
    ignore(elif_kw)
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> ignore(colon)
    |> ignore(newline)
    |> parsec(:statement_list)
    |> tag(:elif)

  if_stmt =
    if_kw
    |> line()
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> ignore(colon)
    |> ignore(newline)
    |> parsec(:statement_list)
    |> repeat(elif_branch)
    |> optional(
      ignore(else_kw)
      |> ignore(colon)
      |> ignore(newline)
      |> parsec(:statement_list)
    )
    |> concat(endif)
    |> reduce(:reduce_if)

  def reduce_if([{[:if], {line, offset}}, condition, {:stmt_list, then}, :endif]) do
    {:if, condition, then, [], nil, {line, offset}}
  end

  def reduce_if([{[:if], {line, offset}}, condition, {:stmt_list, then}, {:stmt_list, otherwise}, :endif]) do
    {:if, condition, then, [], otherwise, {line, offset}}
  end

  def reduce_if([{[:if], {line, offset}}, condition, {:stmt_list, then} | rest]) do
    {elifs, otherwise} = extract_elifs_and_else(rest)
    {:if, condition, then, elifs, otherwise, {line, offset}}
  end

  defp extract_elifs_and_else(ast) do
    extract_elifs_and_else(ast, [], nil)
  end

  defp extract_elifs_and_else([:endif], elifs, otherwise) do
    {Enum.reverse(elifs), otherwise}
  end

  defp extract_elifs_and_else([{:elif, [condition, {:stmt_list, then}]} | rest], elifs, otherwise) do
    extract_elifs_and_else(rest, [{condition, then} | elifs], otherwise)
  end

  defp extract_elifs_and_else([{:stmt_list, otherwise}, :endif], elifs, _) do
    {Enum.reverse(elifs), otherwise}
  end

  while_stmt =
    while_kw
    |> line()
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> ignore(colon)
    |> ignore(newline)
    |> parsec(:statement_list)
    |> concat(done)
    |> reduce(:reduce_while)

  def reduce_while([{[:while], {line, offset}}, condition, {:stmt_list, block}, :done]),
    do: {:while, condition, block, {line, offset}}

  for_stmt =
    for_kw
    |> line()
    |> concat(id())
    |> concat(in_kw)
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> ignore(colon)
    |> ignore(newline)
    |> parsec(:statement_list)
    |> concat(done)
    |> reduce(:reduce_for)

  def reduce_for([
        {[:for], {line, offset}},
        {:var, variable},
        :in,
        expression,
        {:stmt_list, block},
        :done
      ]) do
    {:for, variable, expression, block, {line, offset}}
  end

  wait =
    ignore(wait_kw)
    |> line()
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> tag(:wait)

  return =
    ignore(return_kw)
    |> line()
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> tag(:return)

  defparsecp(
    :statement_list,
    repeat(newline)
    |> parsec(:statement)
    |> repeat(
      times(newline, min: 1)
      |> parsec(:statement)
    )
    |> repeat(newline)
    |> tag(:stmt_list)
  )

  raw_value =
    parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> line()
    |> choice([
      eos(),
      lookahead(string("\n"))
    ])
    |> tag(:raw)
    |> reduce(:reduce_raw)

  def reduce_raw([{:raw, [{[expr], {line, offset}}]}]), do: {:raw, expr, {line, offset}}

  defcombinatorp(
    :statement,
    choice([
      assignment,
      if_stmt,
      while_stmt,
      for_stmt,
      wait,
      return,
      raw_value
    ])
  )

  def exec(string) do
    statement_list(string)
  end
end
