defmodule Pythelix.Scripting.Parser.Expression do
  @moduledoc """
  Parser to parse an expression.

  Grammar:
    <nested> ::= "(" <expr> ")" | <value>
    <expr>  ::= <term0> {"+" | "-" <term0>}
    <term0>   ::= <term1> {"*" | "/" <term1>}
    <term1>     ::= <term2> {<eq_op> <term2>}
    <term2>      ::= <term3> {<ord_op> <term3>}
    <term3>  ::= <term4> {<or> <term4>}
    <term4>   ::= <term5> {<and> <term5>}
    <term5> ::= <not> <term5> | <term_pow>
    <term_pow> ::= <nested> {"**" <term_pow>}
    <ord_op>    ::= > | >= | < | <=
    <eq_op>     ::= != | ==
    <or>     ::= '||'
    <and>    ::= '&&'
    <not>    ::= '!'
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Constants, only: [isolate: 2]
  import Pythelix.Scripting.Parser.Operator

  not_ = string("not") |> isolate(allow_newline: true)
  and_ = string("and") |> replace(:and) |> isolate(space: true, allow_newline: true)
  or_ = string("or") |> replace(:or) |> isolate(space: true, allow_newline: true)

  defp fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  defp fold_infixr([first | rest]) do
    case rest do
      [] -> first
      [op, right | remaining] ->
        {op, [first, fold_infixr([right | remaining])]}
    end
  end

  value_list =
    ignore(lbracket())
    |> concat(
      optional(
        parsec(:expr)
        |> repeat(
          ignore(comma())
          |> parsec(:expr)
        )
        |> optional(ignore(comma()))
      )
      |> tag(:list)
    )
    |> ignore(rbracket())
    |> label("list")
    |> reduce(:reduce_list)

  def reduce_list([{:list, value}]), do: value

  dict_pair =
    parsec(:expr)
    |> ignore(string(":") |> isolate(allow_newline: true))
    |> parsec(:expr)
    |> tag(:element)

  dict =
    ignore(lbrace())
    |> concat(
      optional(
        dict_pair
        |> repeat(
          ignore(comma())
          |> concat(dict_pair)
        )
        |> optional(ignore(comma()))
      )
      |> tag(:dict)
    )
    |> ignore(rbrace())
    |> label("dict")

  set =
    ignore(lbrace())
    |> concat(
      parsec(:expr)
      |> tag(:element)
      |> repeat(
        ignore(comma())
        |> parsec(:expr)
        |> tag(:element)
      )
      |> optional(ignore(comma()))
      |> tag(:set)
    )
    |> ignore(rbrace())
    |> label("set")

  defcombinatorp(
    :nested,
    choice([
      ignore(lparen()) |> parsec(:expr) |> ignore(rparen()),
      value_list,
      dict,
      set,
      parsec({Pythelix.Scripting.Parser.Value, :value})
    ])
  )

  defcombinator(
    :expr,
    parsec(:term_or)
    |> repeat(
      and_
      |> parsec(:term_or)
    )
    |> reduce(:fold_infixl)
  )

  defcombinatorp(
    :term_or,
    parsec(:term_not)
    |> repeat(
      or_
      |> parsec(:term_not)
    )
    |> reduce(:fold_infixl)
  )

  defcombinatorp(
    :term_not,
    choice([
      ignore(not_) |> parsec(:term_not) |> tag(:not),
      parsec(:term_eq)
    ])
    |> label("logic not")
  )

  defcombinatorp(
    :term_eq,
    parsec(:term_cmp)
    |> repeat(
      choice([
        eq(),
        neq(),
        not_in(),
        in_()
      ])
      |> parsec(:term_cmp)
    )
    |> reduce(:fold_infixl)
  )

  defcombinatorp(
    :term_cmp,
    parsec(:term_plus)
    |> repeat(
      choice([gte(), lte(), gt(), lt()])
      |> parsec(:term_plus)
    )
    |> reduce(:fold_infixl)
  )

  defcombinator(
    :term_plus,
    parsec(:term_mul)
    |> repeat(
      choice([plus(), minus()])
      |> parsec(:term_mul)
    )
    |> reduce(:fold_infixl)
  )

  defcombinatorp(
    :term_mul,
    parsec(:term_pow)
    |> repeat(
      choice([mul(), div()])
      |> parsec(:term_pow)
    )
    |> reduce(:fold_infixl)
  )

  defcombinatorp(
    :term_pow,
    parsec(:nested)
    |> repeat(
      pow()
      |> parsec(:term_pow)
    )
    |> reduce(:fold_infixr)
  )

  defparsecp(
    :eval_expr,
    parsec(:expr)
  )

  def eval(string) do
    eval_expr(string)
  end
end
