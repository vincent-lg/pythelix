defmodule Pythelix.Scripting.Parser.Value do
  @moduledoc """
  Parser used to parse a value.

  Grammar:
    <value>      ::= <globals> | <number> | <id_value> | <str>
    <globals>  ::= "true" | "false"
    <number>   ::= <int> | <float>
    <int>      ::= ["-"]<digit>{<digit>}
    <float>    ::= ["-"]<digit>{<digit>}"."<digit>{<digit>}
    <id>       ::= <letter> {<letter> | <valid_ct>}
    <id_value> ::= ["-"]<id>
    <str>      ::= <single> | <double>
    <single>   ::= "'" <any letter> "'"
    <double>   ::= \""" <any letter> \"""
    <digit>    ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
    <letter>   ::= (utf-8 letter)
    <valid_Ct> ::= (utf-8 coutinuation)

  Note: this is NOT to be used to parse an expression (see
  `Pythelix.Scripting.Parser.Expression`).
  """

  import NimbleParsec

  import Pythelix.Scripting.Parser.Constants, only: [id: 0, isolate: 1, isolate: 2]
  import Pythelix.Scripting.Parser.Operator

  alias Pythelix.Scripting.Parser

  globals =
    choice([
      string("True") |> replace(true),
      string("False") |> replace(false),
      string("None") |> replace(:none)
    ])
    |> isolate(allow_newline: true)
    |> label("global name")

  digits =
    ascii_string([?0..?9], min: 1)
    |> label("digits")

  int =
    optional(string("-"))
    |> concat(digits)
    |> isolate(allow_newline: true)
    |> reduce(:to_integer)
    |> label("integer")

  defp to_integer(acc), do: acc |> Enum.join() |> String.to_integer(10)

  float =
    optional(string("-"))
    |> concat(digits)
    |> ascii_string([?.], 1)
    |> concat(digits)
    |> isolate(allow_newline: true)
    |> reduce(:to_float)
    |> label("float")

  defp to_float(acc), do: acc |> Enum.join() |> String.to_float()

  number =
    choice([float, int])
    |> label("number")

  time =
    digits
    |> ignore(string(":"))
    |> concat(digits)
    |> optional(
      ignore(string(":"))
      |> concat(digits)
    )
    |> isolate(allow_newline: true)
    |> reduce(:to_time)
    |> label("time")

  defp to_time([hour, minute]) do
    {:time, String.to_integer(hour), String.to_integer(minute), 0}
  end

  defp to_time([hour, minute, second]) do
    {:time, String.to_integer(hour), String.to_integer(minute), String.to_integer(second)}
  end

  duration_unit = ascii_char([?s, ?m, ?h, ?d, ?o, ?y])

  duration_part =
    digits
    |> concat(duration_unit)
    |> reduce(:to_duration_part)

  duration =
    times(duration_part, min: 1)
    |> isolate(allow_newline: true)
    |> reduce(:to_duration)
    |> label("duration")

  defp to_duration_part([digits, unit]) do
    {String.to_integer(digits), <<unit>>}
  end

  defp to_duration(parts) do
    map =
      Enum.reduce(parts, %{seconds: 0, minutes: 0, hours: 0, days: 0, months: 0, years: 0}, fn
        {n, "s"}, acc -> %{acc | seconds: n}
        {n, "m"}, acc -> %{acc | minutes: n}
        {n, "h"}, acc -> %{acc | hours: n}
        {n, "d"}, acc -> %{acc | days: n}
        {n, "o"}, acc -> %{acc | months: n}
        {n, "y"}, acc -> %{acc | years: n}
      end)

    {:duration, map}
  end

  defcombinator :string,
    choice([
      Parser.String.quoted("'''", multiline: true, label: "triple-quote with ticks"),
      Parser.String.quoted(~s/"""/, multiline: true, label: "triple-quote with double quotes"),
      Parser.String.quoted("'", label: "single quote"),
      Parser.String.quoted(~s/"/, label: "double quote")
    ])

  def escape(chars) do
    chars
    |> Enum.join("")
    |> String.replace("\\n", "\n")
  end

  defcombinator(
    :arg,
    choice([
      id()
      |> ignore(equal())
      |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
      |> tag(:kwarg),
      parsec({Pythelix.Scripting.Parser.Expression, :expr})
    ])
  )

  defcombinator(
    :entity,
    ignore(string("!"))
    |> utf8_string([{:not, ?!}], min: 1)
    |> ignore(string("!"))
    |> unwrap_and_tag(:entity)
    |> isolate()
  )

  defcombinatorp(
    :function,
    id()
    |> ignore(lparen())
    |> optional(
      parsec(:arg)
      |> repeat(
        ignore(comma())
        |> parsec(:arg)
      )
      |> tag(:args)
    )
    |> ignore(rparen())
    |> tag(:function)
    |> reduce(:reduce_function)
  )

  def reduce_function([{:function, [{:var, name}]}]) do
    {:function, name, [], %{}}
  end

  def reduce_function([{:function, [{:var, name}, {:args, args}]}]) do
    {args, kwargs} =
      args
      |> Enum.reduce({[], %{}}, fn
        {:kwarg, [{:var, key}, value]}, {args, kwargs} -> {args, Map.put(kwargs, key, value)}
        value, {args, kwargs} -> {[value | args], kwargs}
      end)

    {:function, name, args, kwargs}
  end

  defcombinatorp(
    :formatted_string,
    ignore(string("f"))
    |> parsec(:string)
    |> unwrap_and_tag(:formatted)
    |> isolate(allow_newline: true)
  )

  defcombinator :getitem,
    choice([
      parsec(:formatted_string),
      parsec(:string) |> isolate(),
      parsec(:function),
      id()
    ])
    |> times(
      ignore(lbracket())
      |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
      |> ignore(rbracket()),
      min: 1
    )
    |> tag(:getitem)

  defcombinator(
    :nested_values,
    choice([
      globals,
      time,
      duration,
      number,
      parsec(:formatted_string),
      parsec(:string) |> isolate(allow_newline: true),
      ignore(string("-")) |> concat(parsec(:function)) |> tag(:neg),
      ignore(string("-")) |> concat(id()) |> tag(:neg),
      parsec(:function),
      parsec(:entity),
      parsec(:getitem),
      id()
    ])
    |> optional(
      repeat(
        ignore(dot())
        |> choice([parsec(:function), parsec(:getitem), id()])
        |> reduce(:reduce_nested_values)
      )
      |> tag(:nested)
    )
    |> reduce(:reduce_nested_values)
  )

  def reduce_nested_values([value, {:nested, []}]), do: value
  def reduce_nested_values(value), do: value

  defcombinator(
    :value,
    parsec(:nested_values)
  )
end
