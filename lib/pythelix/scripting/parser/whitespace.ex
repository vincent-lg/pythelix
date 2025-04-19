defmodule Pythelix.Scripting.Parser.Whitespace do
  @moduledoc """
  Parser for whitespace.

  You probably want to use the `isolate/1` combinator. In this case,
  import it from `Pythelix.Scripting.Parser.Constants` instead:

  ```elixir
  defmodule Parser do
    import Pythelix.Scripting.Parser.Constants, only: [isolate: 1]

    parser =
      string("ok")
      |> isolate()
  end
  ```
  """

  import NimbleParsec

  @whitespace "[[:space:]-[\n]]"
  @end_symbol "[[:space:][+*/\(\)=<>!:,.\\[\\]][\\-]]"

  @whitespace_range Unicode.Set.to_utf8_char(@whitespace) |> elem(1)
  @end_symbol_range Unicode.Set.to_utf8_char(@end_symbol) |> elem(1)

  def clear_whitespace(space) do
    ignore(
      choice([
        utf8_char(@whitespace_range) |> times(min: (space && 1) || 0) |> label("whitespace"),
        empty()
      ])
    )
  end

  def check_end_symbol do
    lookahead(
      choice([
        utf8_char(@end_symbol_range) |> times(min: 1) |> label("end symbol"),
        eos()
      ])
    )
  end
end
