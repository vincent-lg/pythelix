defmodule Pythelix.Command.Syntax.Parser do
  @moduledoc """
  A parser responsible for turning tye command syntax into a grammar.
  """

  import NimbleParsec
  import Pythelix.Scripting.Parser.Operator, only: [lparen: 0, rparen: 0]

  def handle_arg(<<?#, _::binary>>, %{escape: false} = context, _, _), do: {:halt, context}
  def handle_arg(<<?>, _::binary>>, %{escape: false} = context, _, _), do: {:halt, context}

  def handle_arg(<<?\\, _::binary>>, context, _, _),
    do: {:cont, Map.put(context, :escape, true)}

  def handle_arg(_, context, _, _), do: {:cont, Map.put(context, :escape, false)}

  defparsec(
    :str_arg,
    ignore(ascii_char([?<]))
    |> repeat_while(
      utf8_char([{:not, ?\n}]),
      {__MODULE__, :handle_arg, []}
    )
    |> ignore(ascii_char([?>]))
    |> reduce({List, :to_string, []})
    |> label("arg")
    |> unwrap_and_tag(:string)
    |> tag(:arg)
  )

  defparsec(
    :num_arg,
    ignore(ascii_char([?#]))
    |> repeat_while(
      utf8_char([{:not, ?\n}]),
      {__MODULE__, :handle_arg, []}
    )
    |> ignore(ascii_char([?#]))
    |> reduce({List, :to_string, []})
    |> label("number")
    |> unwrap_and_tag(:int)
    |> tag(:arg)
  )

  defcombinatorp(
    :keyword_or_symbol,
    utf8_string([not: ?\s, not: ?(, not: ?)], min: 1)
    |> tag(:keyword)
  )

  defcombinatorp(
    :unit,
    choice([
      parsec(:str_arg),
      parsec(:num_arg),
      parsec(:keyword_or_symbol)
    ])
  )

  defcombinatorp(
    :units,
    parsec(:unit)
    |> repeat(
      ignore(optional(ascii_char([?\s])))
      |> parsec(:unit)
    )
  )

  defcombinatorp(
    :branch,
    choice([
      ignore(lparen())
      |> parsec(:branch)
      |> ignore(rparen())
      |> tag(:opt),
      parsec(:units)
    ])
  )

  defcombinatorp(
    :full_syntax,
    ignore(optional(ascii_char([?\s])))
    |> parsec(:branch)
    |> repeat(
      ignore(ascii_char([?\s]))
      |> parsec(:branch)
    )
    |> eos()
  )

  defparsec(:syntax, parsec(:full_syntax))
end
