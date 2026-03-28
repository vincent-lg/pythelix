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
    utf8_string([not: ?\s, not: ?(, not: ?), not: ?<, not: ?>, not: ?#], min: 1)
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

  @doc """
  Classify keywords vs delimiters in a parsed syntax pattern.

  A token is a keyword if it is more than one character long OR surrounded
  by spaces in the syntax string. Otherwise it is a delimiter.
  """
  def classify(syntax_string, tokens) do
    {classified, _pos} = do_classify(syntax_string, tokens, 0)
    classified
  end

  defp do_classify(_string, [], pos), do: {[], pos}

  defp do_classify(string, [{:arg, [{:string, _}]} = token | rest], pos) do
    pos = skip_spaces(string, pos)
    {end_pos, 1} = :binary.match(string, ">", [{:scope, {pos, byte_size(string) - pos}}])
    {rest_classified, final_pos} = do_classify(string, rest, end_pos + 1)
    {[token | rest_classified], final_pos}
  end

  defp do_classify(string, [{:arg, [{:int, _}]} = token | rest], pos) do
    pos = skip_spaces(string, pos)
    {first_hash, 1} = :binary.match(string, "#", [{:scope, {pos, byte_size(string) - pos}}])
    {second_hash, 1} = :binary.match(string, "#", [{:scope, {first_hash + 1, byte_size(string) - first_hash - 1}}])
    {rest_classified, final_pos} = do_classify(string, rest, second_hash + 1)
    {[token | rest_classified], final_pos}
  end

  defp do_classify(string, [{:keyword, [kw]} | rest], pos) do
    pos = skip_spaces(string, pos)
    kw_size = byte_size(kw)
    after_pos = pos + kw_size

    before_is_space = pos == 0 or :binary.at(string, pos - 1) == ?\s
    after_is_space = after_pos >= byte_size(string) or :binary.at(string, after_pos) == ?\s

    tag =
      if kw_size > 1 or (before_is_space and after_is_space) do
        :keyword
      else
        :delimiter
      end

    {rest_classified, final_pos} = do_classify(string, rest, after_pos)
    {[{tag, [kw]} | rest_classified], final_pos}
  end

  defp do_classify(string, [{:opt, branch} | rest], pos) do
    pos = skip_spaces(string, pos)
    # Skip opening paren
    {classified_branch, pos} = do_classify(string, branch, pos + 1)
    # Skip closing paren
    pos = skip_spaces(string, pos)
    {rest_classified, final_pos} = do_classify(string, rest, pos + 1)
    {[{:opt, classified_branch} | rest_classified], final_pos}
  end

  defp skip_spaces(string, pos) do
    if pos < byte_size(string) and :binary.at(string, pos) == ?\s do
      skip_spaces(string, pos + 1)
    else
      pos
    end
  end
end
