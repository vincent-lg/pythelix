defmodule Pythelix.Scripting.Parser do
  @moduledoc """
  Parser module, to access sub-parsers as needed.

  There are two different types of operations: `eval/1`, which consists
  in parsing an expression, and `exec/1`, which consists in parsing
  a list of statements.
  """

  @doc """
  Evaluates an expression.
  """
  @spec eval(binary()) :: {:ok, term()} | {:error, binary()}
  def eval(expression) do
    expression
    |> Pythelix.Scripting.Parser.Expression.eval()
    |> unwrap()
  end

  @doc """
  Executes a list of statements.

  This function allows to parse a full script (a multi-l;ine statements).
  """
  @spec exec(binary()) :: {:ok, term()} | {:error, binary()}
  def exec(code) do
    code
    |> Pythelix.Scripting.Parser.Statement.exec()
    |> unwrap()
  end

  defp unwrap({:ok, [ast], <<>>, _, _line, _offset}), do: {:ok, ast}

  defp unwrap({:ok, ast, rest, _, _, _}) do
    {:error, "could not parse #{inspect(rest)}, ast=#{inspect(ast)}, len=#{length(ast)}"}
  end

  defp unwrap({:error, reason, _rest, _context, _line, _offset}), do: {:error, reason}
end
