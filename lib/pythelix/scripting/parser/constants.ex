defmodule Pythelix.Scripting.Parser.Constants do
  @moduledoc """
  Parser containing constants used in the general parser.

  Most other parsers will need its features at some point.
  But they probably only need to import some features.
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Whitespace, only: [clear_whitespace: 1, check_end_symbol: 0]

  @reserved_sym ["True", "False", "None", "not", "and", "or", "endif", "done"]
  @id_start "[[:L:][:Nl:][:Other_ID_Start:]-[:Pattern_Syntax:]-[:Pattern_White_Space:][_]]"
  @id_continue "[[:ID_Start:][:Mn:][:Mc:][:Nd:][:Pc:][:Other_ID_Continue:]-[:Pattern_Syntax:]-[:Pattern_White_Space:][_]]"

  @id_start "[[:L:][:Nl:][:Other_ID_Start:]-[:Pattern_Syntax:]-[:Pattern_White_Space:][_]]"
  @id_continue "[[:ID_Start:][:Mn:][:Mc:][:Nd:][:Pc:][:Other_ID_Continue:]-[:Pattern_Syntax:]-[:Pattern_White_Space:][_]]"
  @id_start_range Unicode.Set.to_utf8_char(@id_start) |> elem(1)
  @id_continue_range Unicode.Set.to_utf8_char(@id_continue) |> elem(1)

  @doc """
  Remove whitespaces before the parser, make sure there are end symbols after.

  This function will wrap the given parser to clear whitespaces before it,
  and then check for end symbols after it. This is pretty useful
  for a lot of parsers, since it allows to avoid conflicts between
  global names and variable names for instance.
  """
  def isolate(parser, opts \\ []) do
    space = Keyword.get(opts, :space, false)
    check = Keyword.get(opts, :check, true)

    parser =
      clear_whitespace(space)
      |> concat(parser)

    if check do
      parser
      |> concat(check_end_symbol())
    else
      parser
    end
  end

  def id do
    lookahead_not(
      choice(
        @reserved_sym
        |> Enum.map(&string/1)
      )
      |> isolate()
    )
    |> utf8_char(@id_start_range)
    |> utf8_string(@id_continue_range, min: 0)
    |> isolate()
    |> post_traverse({__MODULE__, :to_varname, []})
    |> unwrap_and_tag(:var)
    |> label("variable")
  end

  def to_varname(rest, acc, context, _line, _offset) do
    name = acc |> Enum.reverse() |> List.to_string()

    {rest, [name], context}
  end
end
