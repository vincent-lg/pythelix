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
  def parse(input) do
    input
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      tokenize_line(line, line_number)
    end)
    |> Enum.reduce_while({[], :normal}, fn token, {stack, mode} ->
      case parse_token(token, stack, mode) do
        {:ok, stack, mode} -> {:cont, {stack, mode}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> tabulate_result()
  end

  defp tokenize_line(line, line_number) do
    Regex.scan(~r/(?:""")|(?:''')|(?:[\p{L}\p{N}])+|[^\s\p{L}\p{N}]/u, line)
    |> List.flatten()
    |> Enum.map(fn token -> {token, line_number} end)
    |> IO.inspect(label: "tokens")
  end

  defp tabulate_result({:error, _} = error), do: error
  defp tabulate_result({[], :normal}), do: :complete
  defp tabulate_result({_, :string}), do: {:need_more, "still inside a string"}

  defp tabulate_result({[{symbol, line} | _], _}) do
    {:need_more, "no close of symbol #{inspect(symbol)} started on line #{line}"}
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
