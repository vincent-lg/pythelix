defmodule Pythelix.Command.Signature.Parser do
  @moduledoc """
  Parser for the command signature.

  This simple parser parses a method signature with type hints.
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Constants, only: [id: 0, isolate: 1, isolate: 2]
  import Pythelix.Scripting.Parser.Operator, only: [lparen: 0, rparen: 0]

  defparsec(
    :entity,
    ignore(
      string("Entity") |> isolate()
    )
    |> ignore(
      string("[") |> isolate(check: false)
    )
    |> parsec({Pythelix.Scripting.Parser.Value, :string})
    #|> isolate()
    |> ignore(
      string("]") |> isolate(check: false)
    )
    |> unwrap_and_tag(:entity)
  )

  defparsec(
    :hint,
    choice([
      string("int") |> isolate() |> replace(:int),
      string("float") |> isolate() |> replace(:float),
      parsec(:entity)
    ])
  )

  defparsec(
    :arg,
    id()
    |> optional(
      ignore(
        string(":") |> isolate()
      )
      |> parsec(:hint)
      |> unwrap_and_tag(:hint)
    )
    |> optional(
      ignore(
        string("=") |> isolate(check: false)
      )
      |> parsec({Pythelix.Scripting.Parser.Expression, :expr})
      |> unwrap_and_tag(:default)
    )
    |> tag(:arg)
  )

  defparsec(
    :signature,
    optional(
      parsec(:arg)
      |> repeat(
        ignore(string(",") |> isolate())
        |> parsec(:arg)
      )
    )
  )

  defparsec(
    :full_signature,
    id()
    |> ignore(lparen())
    |> parsec(:signature)
    |> ignore(rparen())
    |> eos()
  )

  defparsec(
    :definition,
    parsec(:full_signature)
  )
end
