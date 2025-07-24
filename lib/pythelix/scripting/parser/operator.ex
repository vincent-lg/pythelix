defmodule Pythelix.Scripting.Parser.Operator do
  @moduledoc """
  Parser module containing operators as functions.
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Constants, only: [isolate: 1, isolate: 2]

  def plus do
    ascii_char([?+])
    |> replace(:+)
    |> label("+")
    |> isolate(check: false)
  end

  def minus do
    ascii_char([?-])
    |> replace(:-)
    |> label("-")
    |> isolate(check: false)
  end

  def mul do
    ascii_char([?*])
    |> replace(:*)
    |> label("*")
    |> isolate(check: false)
  end

  def div do
    ascii_char([?/])
    |> replace(:/)
    |> label("/")
    |> isolate(check: false)
  end

  def lparen do
    ascii_char([?(])
    |> label("(")
    |> isolate(check: false)
  end

  def rparen do
    ascii_char([?)])
    |> label(")")
    |> isolate(check: false)
  end

  def lbracket do
    ascii_char([?[])
    |> label("[")
    |> isolate(check: false)
  end

  def rbracket do
    ascii_char([?]])
    |> label("]")
    |> isolate()
  end

  def lbrace do
    ascii_char([?{])
    |> label("{")
    |> isolate(check: false)
  end

  def rbrace do
    ascii_char([?}])
    |> label("}")
    |> isolate(check: false)
  end

  def comma do
    string(",")
    |> label(",")
    |> isolate()
  end

  def gt do
    string(">")
    |> replace(:>)
    |> isolate(check: false)
  end

  def gte do
    string(">=")
    |> replace(:>=)
    |> isolate(check: false)
  end

  def lt do
    string("<")
    |> replace(:<)
    |> isolate(check: false)
  end

  def lte do
    string("<=")
    |> replace(:<=)
    |> isolate(check: false)
  end

  def eq do
    string("==")
    |> replace(:==)
    |> isolate(check: false)
  end

  def neq do
    string("!=")
    |> replace(:!=)
    |> isolate(check: false)
  end

  def in_ do
    string("in")
    |> replace(:in)
    |> isolate(space: true)
  end

  def not_in do
    string("not")
    |> times(string(" "), min: 1)
    |> string("in")
    |> isolate(space: true)
    |> replace(:not_in)
  end

  def plus_eq do
    string("+=")
    |> replace(:"+=")
    |> isolate(check: false)
  end

  def minus_eq do
    string("-=")
    |> replace(:"-=")
    |> isolate(check: false)
  end

  def mul_eq do
    string("*=")
    |> replace(:"*=")
    |> isolate(check: false)
  end

  def div_eq do
    string("/=")
    |> replace(:"/=")
    |> isolate(check: false)
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
