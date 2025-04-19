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
  else_kw = string("else") |> label("else") |> replace(:else) |> isolate()
  while_kw = string("while") |> label("while") |> replace(:while) |> isolate(space: true)
  endif = string("endif") |> label("endif") |> replace(:endif) |> isolate()
  done = string("done") |> label("done") |> replace(:done) |> isolate()
  for_kw = string("for") |> label("for") |> replace(:for) |> isolate(space: true)
  in_kw = string("in") |> label("in") |> replace(:in) |> isolate(space: true)

  assignment =
    id()
    |> repeat(
      ignore(dot())
      |> concat(id())
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
    names = for {var, name} <- nested, do: name
    {opeq, names, value, {line, offset}}
  end

  if_stmt =
    if_kw
    |> line()
    |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
    |> ignore(colon)
    |> ignore(newline)
    |> parsec(:statement_list)
    |> optional(
      ignore(else_kw)
      |> ignore(colon)
      |> ignore(newline)
      |> parsec(:statement_list)
    )
    |> concat(endif)
    |> reduce(:reduce_if)

  def reduce_if([{[:if], {line, offset}}, condition, {:stmt_list, then}, :endif]) do
    {:if, condition, then, nil, {line, offset}}
  end

  def reduce_if([
        {[:if], {line, offset}},
        condition,
        {:stmt_list, then},
        {:stmt_list, otherwise},
        :endif
      ]) do
    {:if, condition, then, otherwise, {line, offset}}
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
      raw_value
    ])
  )

  def exec(string) do
    statement_list(string)
  end
end
