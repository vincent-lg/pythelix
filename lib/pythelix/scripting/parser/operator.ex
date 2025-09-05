defmodule Pythelix.Scripting.Parser.Operator do
  @moduledoc """
  Parser module containing operators as functions.
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Constants, only: [isolate: 2]

  def plus do
    ascii_char([?+])
    |> replace(:+)
    |> label("+")
    |> isolate(check: false, allow_newline: true)
  end

  def minus do
    ascii_char([?-])
    |> replace(:-)
    |> label("-")
    |> isolate(check: false, allow_newline: true)
  end

  def mul do
    ascii_char([?*])
    |> replace(:*)
    |> label("*")
    |> isolate(check: false, allow_newline: true)
  end

  def div do
    ascii_char([?/])
    |> replace(:/)
    |> label("/")
    |> isolate(check: false, allow_newline: true)
  end

  def pow do
    string("**")
    |> replace(:**)
    |> label("**")
    |> isolate(check: false, allow_newline: true)
  end

  def lparen do
    ascii_char([?(])
    |> label("(")
    |> isolate(check: false, allow_newline: true)
  end

  def rparen do
    ascii_char([?)])
    |> label(")")
    |> isolate(check: false, allow_newline: true)
  end

  def lbracket do
    ascii_char([?[])
    |> label("[")
    |> isolate(check: false, allow_newline: true)
  end

  def rbracket do
    ascii_char([?]])
    |> label("]")
    |> isolate(allow_newline: true)
  end

  def lbrace do
    ascii_char([?{])
    |> label("{")
    |> isolate(check: false, allow_newline: true)
  end

  def rbrace do
    ascii_char([?}])
    |> label("}")
    |> isolate(check: false, allow_newline: true)
  end

  def comma do
    string(",")
    |> label(",")
    |> isolate(allow_newline: true, check: false)
  end

  def gt do
    string(">")
    |> replace(:>)
    |> isolate(check: false, allow_newline: true)
  end

  def gte do
    string(">=")
    |> replace(:>=)
    |> isolate(check: false, allow_newline: true)
  end

  def lt do
    string("<")
    |> replace(:<)
    |> isolate(check: false, allow_newline: true)
  end

  def lte do
    string("<=")
    |> replace(:<=)
    |> isolate(check: false, allow_newline: true)
  end

  def eq do
    string("==")
    |> replace(:==)
    |> isolate(check: false, allow_newline: true)
  end

  def neq do
    string("!=")
    |> replace(:!=)
    |> isolate(check: false, allow_newline: true)
  end

  def in_ do
    string("in")
    |> replace(:in)
    |> isolate(space: true, allow_newline: true)
  end

  def not_in do
    string("not")
    |> times(string(" "), min: 1)
    |> string("in")
    |> isolate(space: true, allow_newline: true)
    |> replace(:not_in)
  end

  def plus_eq do
    string("+=")
    |> replace(:"+=")
    |> isolate(check: false, allow_newline: true)
  end

  def minus_eq do
    string("-=")
    |> replace(:"-=")
    |> isolate(check: false, allow_newline: true)
  end

  def mul_eq do
    string("*=")
    |> replace(:"*=")
    |> isolate(check: false, allow_newline: true)
  end

  def div_eq do
    string("/=")
    |> replace(:"/=")
    |> isolate(check: false, allow_newline: true)
  end

  def dot do
    string(".")
    |> replace(:.)
    |> label("dot")
    |> isolate(check: false)
  end

  def equal do
    string("=")
    |> replace(:=)
    |> isolate(check: false)
  end
end
