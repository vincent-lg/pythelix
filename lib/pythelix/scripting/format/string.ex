defmodule Pythelix.Scripting.Format.String do
  @moduledoc """
  A string, ready to be formatted.
  """

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script

  @enforce_keys [:string, :variables]
  defstruct [:string, :variables]

  @typedoc "a formatted string (f-string)"
  @type t() :: %Format.String{string: binary(), variables: map()}

  @spec new(Script.t(), binary()) :: t()
  def new(%Script{} = script, string) do
    variables =
      script.variables
      |> Enum.map(fn {name, _} ->
        {name, Script.get_variable_value(script, name)}
      end)
      |> Map.new()

    %Format.String{string: string, variables: variables}
  end

  @doc """
  Format the variables and return the formatted string.

  Args:

  * format (Format.String): the formatted string.
  """
  @spec format(Format.String.t()) :: String.t()
  def format(string) when is_binary(string), do: string

  def format(%Format.String{} = format_string) do
    script =
      format_string.variables
      |> Enum.reduce(%Script{bytecode: 0}, fn {name, value}, script ->
        Script.write_variable(script, name, value)
      end)

    do_split(String.graphemes(format_string.string), [], "", :text)
    |> maybe_format(script)
  end

  defp do_split([], acc, buffer, :text), do: {:ok, Enum.reverse([buffer | acc]) |> Enum.reject(&(&1 == ""))}
  defp do_split([], _acc, _buffer, :brace), do: {:error, :unmatched_brace}

  defp do_split(["{" | rest], acc, buffer, :text) do
    case rest do
      ["{" | tail] -> do_split(tail, acc, buffer <> "{", :text)
      _ -> do_split(rest, [buffer | acc], "", :brace)
    end
  end

  defp do_split(["}" | rest], acc, buffer, :brace) do
    case rest do
      ["}" | tail] -> do_split(tail, acc, buffer <> "}", :brace)
      _ -> do_split(rest, [{:format, buffer} | acc], "", :text)
    end
  end

  defp do_split([char | rest], acc, buffer, mode), do: do_split(rest, acc, buffer <> char, mode)

  defp maybe_format({:ok, pattern}, script) do
    pattern
    |> Enum.map(fn
      {:format, code} ->
        case Scripting.eval(code, script: script) do
          {:ok, value} ->
            to_string(value)

          {:error, error} ->
            inspect(error)
        end

      plain ->
        plain
    end)
    |> Enum.join()
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Format.String{} = format_string, opts) do
      to_doc(Format.String.format(format_string), opts)
    end
  end
end
