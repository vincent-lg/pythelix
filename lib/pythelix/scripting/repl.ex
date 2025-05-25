defmodule Pythelix.Scripting.REPL do
  @moduledoc """
  A simple and minimalist parser to check that an instruction is complete
  or that more input is needed. It doesn't process any token and doesn't
  use the official Pythelix parser. This is simply intended to be used
  with a REPL like the mix script task.
  """

  @doc """
  Parses the specified input and returns its status:

  Args:

  * input (string): the user input.

  Returns:

  * `:complete`: the provided script can be sent to the parser.
  * `{:need_more, reason}`: more input is needed.
  * `{:error, reason}`: the input cannot be parsed.
  """
  @spec parse(binary()) :: :complete | {:need_more, binary()} | {:error, binary()}
  def parse(input, opts \\ []) do
    input
    |> tokenize()
    |> Enum.reduce_while({[], :normal}, fn token, {stack, mode} ->
      case parse_token(token, stack, mode) do
        {:ok, stack, mode} -> {:cont, {stack, mode}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> tap(fn result ->
      if opts[:debug] do
        IO.inspect(result)
      end

      :ok
    end)
    |> tabulate_result()
  end

  defp tokenize(input) do
    regex = ~r/[\p{L}\p{N}]+|[^\p{L}\p{N}\s]|[\n]/u
    tokens = Regex.scan(regex, input) |> List.flatten()

    {annotated, _line} =
      Enum.map_reduce(tokens, 1, fn token, line ->
        new_line = if token == "\n", do: line + 1, else: line
        {{token, line}, new_line}
      end)

    annotated
  end

  defp tabulate_result({:error, _} = error), do: error
  defp tabulate_result({[{:tic, _}], :maybe_3_tic}), do: :complete
  defp tabulate_result({[{:quote, _}], :maybe_3_quote}), do: :complete
  defp tabulate_result({[], :normal}), do: :complete
  defp tabulate_result({_, :maybe_close_2_tic}), do: {:need_more, "still inside a multi-line string"}
  defp tabulate_result({_, :multistring}), do: {:need_more, "still inside a multi-line string"}
  defp tabulate_result({_, :string}), do: {:need_more, "still inside a string"}

  defp tabulate_result({[{symbol, line} | _], _}) do
    {:need_more, "no close of symbol #{inspect(symbol)} started on line #{line}"}
  end

  # Multiline strings.
  defp parse_token(_token, stack, :escape_multistring) do
    {:ok, stack, :multistring}
  end

  # All non-multiline strings.
  defp parse_token(_token, stack, :escape_string) do
    {:ok, stack, :string}
  end

  defp parse_token({"\n", line}, _, :string) do
    {:error, "syntax error on line #{line}: the string should be closed before the end of line"}
  end

  defp parse_token({"\\", _line}, stack, :string) do
    {:ok, stack, :escape_string}
  end

  defp parse_token({"\\", _line}, stack, :multistring) do
    {:ok, stack, :escape_multistring}
  end

  # Strings with triple quotes
  defp parse_token({"\"", _}, [{:quote, _} | stack], :maybe_close_2_quote) do
    {:ok, stack, :normal}
  end

  defp parse_token(_, [{:quote, _} | _] = stack, :maybe_close_2_quote) do
    {:ok, stack, :multistring}
  end

  defp parse_token({"\"", _}, [{:quote, _} | _] = stack, :maybe_close_quote) do
    {:ok, stack, :maybe_close_2_quote}
  end

  defp parse_token(_, [{:quote, _} | _] = stack, :maybe_close_quote) do
    {:ok, stack, :multistring}
  end

  defp parse_token({"\"", _}, [{:quote, _} | _] = stack, :multistring) do
    {:ok, stack, :maybe_close_quote}
  end

  defp parse_token({"\"", _line}, [{:quote, _} | _] = stack, :maybe_3_quote) do
    {:ok, stack, :multistring}
  end

  defp parse_token(token, [{:quote, _} | stack], :maybe_3_quote) do
    parse_token(token, stack, :normal)
  end

  # Strings with triple tics
  defp parse_token({"'", _}, [{:tic, _} | stack], :maybe_close_2_tic) do
    {:ok, stack, :normal}
  end

  defp parse_token(_, [{:tic, _} | _] = stack, :maybe_close_2_tic) do
    {:ok, stack, :multistring}
  end

  defp parse_token({"'", _}, [{:tic, _} | _] = stack, :maybe_close_tic) do
    {:ok, stack, :maybe_close_2_tic}
  end

  defp parse_token(_, [{:tic, _} | _] = stack, :maybe_close_tic) do
    {:ok, stack, :multistring}
  end

  defp parse_token({"'", _}, [{:tic, _} | _] = stack, :multistring) do
    {:ok, stack, :maybe_close_tic}
  end

  defp parse_token({"'", _line}, [{:tic, _} | _] = stack, :maybe_3_tic) do
    {:ok, stack, :multistring}
  end

  defp parse_token(token, [{:tic, _} | stack], :maybe_3_tic) do
    parse_token(token, stack, :normal)
  end

  # Strings with double quotes
  defp parse_token({"\"", line}, stack, :normal) do
    {:ok, [{:quote, line} | stack], :string}
  end

  defp parse_token({"\"", _}, [{:quote, _} | _] = stack, :string) do
    {:ok, stack, :maybe_3_quote}
  end

  defp parse_token({"\"", line}, [{other, other_line} | _], :string) do
    {:error, "found \" on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({"\"", line}, _, :string) do
    {:error, "quote \" at line #{line} doesn't close anything"}
  end

  # Strings with single quotes
  defp parse_token({"'", line}, stack, :normal) do
    {:ok, [{:tic, line} | stack], :string}
  end

  defp parse_token({"'", _}, [{:tic, _} | _] = stack, :string) do
    {:ok, stack, :maybe_3_tic}
  end

  defp parse_token({"'", line}, [{other, other_line} | _], :string) do
    {:error, "found ' on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({"'", line}, _, :string) do
    {:error, "tic ' at line #{line} doesn't close anything"}
  end

  # All else in strings should be ignored.
  defp parse_token(_, stack, :multistring) do
    {:ok, stack, :multistring}
  end

  defp parse_token(_, stack, :string) do
    {:ok, stack, :string}
  end

  # Parenthesis
  defp parse_token({"(", line}, stack, :normal) do
    {:ok, [{:lp, line} | stack], :normal}
  end

  defp parse_token({")", _}, [{:lp, _} | stack], :normal) do
    {:ok, stack, :normal}
  end

  defp parse_token({")", line}, [{other, other_line} | _], :normal) do
    {:error, "found ) on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({")", line}, _, :normal) do
    {:error, "right parent ) at line #{line} doesn't close anything"}
  end

  # Brackets
  defp parse_token({"[", line}, stack, :normal) do
    {:ok, [{:lb, line} | stack], :normal}
  end

  defp parse_token({"]", _}, [{:lb, _} | stack], :normal) do
    {:ok, stack, :normal}
  end

  defp parse_token({"]", line}, [{other, other_line} | _], :normal) do
    {:error, "found ] on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({"]", line}, _, :normal) do
    {:error, "right bracket ] at line #{line} doesn't close anything"}
  end

  # If...endif keywords
  defp parse_token({"if", line}, stack, :normal) do
    {:ok, [{:if, line} | stack], :normal}
  end

  defp parse_token({"endif", _}, [{:if, _} | stack], :normal) do
    {:ok, stack, :normal}
  end

  defp parse_token({"endif", line}, [{other, other_line} | _], :normal) do
    {:error, "found 'endif' on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({"endif", line}, _, :normal) do
    {:error, "'endif' at line #{line} doesn't close an 'if' condition"}
  end

  # While-for...done
  defp parse_token({"for", line}, stack, :normal) do
    {:ok, [{:for, line} | stack], :normal}
  end

  defp parse_token({"while", line}, stack, :normal) do
    {:ok, [{:while, line} | stack], :normal}
  end

  defp parse_token({"done", _}, [{:for, _} | stack], :normal) do
    {:ok, stack, :normal}
  end

  defp parse_token({"done", _}, [{:while, _} | stack], :normal) do
    {:ok, stack, :normal}
  end

  defp parse_token({"done", line}, [{other, other_line} | _], :normal) do
    {:error, "found 'done' on line #{line}, but unclosed #{other} at #{other_line}"}
  end

  defp parse_token({"done", line}, _, :normal) do
    {:error, "'ddone' keyword at line #{line} doesn't close anything"}
  end

  # Anything else is fair game.
  defp parse_token({_, _}, stack, :normal) do
    {:ok, stack, :normal}
  end
end
