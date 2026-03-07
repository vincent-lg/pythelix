defmodule Pythelix.Scripting.Format.String do
  @moduledoc """
  A string, ready to be formatted.
  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script

  @enforce_keys [:string, :variables]
  defstruct [:string, :variables]

  @typedoc "a formatted string (f-string)"
  @type t() :: %Format.String{string: binary(), variables: map()}

  @spec new(Script.t(), binary()) :: t()
  def new(%Script{} = script, string) do
    variables = script.variables

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
    script = %Script{id: "format", bytecode: [], variables: format_string.variables}

    do_split(String.graphemes(format_string.string), [], "", :text)
    |> maybe_format(script)
  end

  defp do_split([], acc, buffer, :text),
    do: {:ok, Enum.reverse([buffer | acc]) |> Enum.reject(&(&1 == ""))}

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

  @doc """
  Format with viewer-aware entity name resolution.

  Each expression segment that evaluates to an entity will have its name
  resolved via `__namefor__(viewer)` instead of using `to_string`.

  Returns `{formatted_string, entities}` where `entities` is a `MapSet`
  of all `Entity` structs encountered in the f-string expressions.
  """
  def format_for(string, _viewer) when is_binary(string), do: {string, MapSet.new()}

  def format_for(%Format.String{} = format_string, viewer) do
    script = %Script{id: "format", bytecode: [], variables: format_string.variables}

    do_split(String.graphemes(format_string.string), [], "", :text)
    |> maybe_format_for(script, viewer)
  end

  @doc """
  Extract all entities referenced in the f-string expressions.

  Evaluates each expression segment and collects those whose result is
  an entity. Used for auto-exclusion before formatting.
  """
  def extract_entities(string) when is_binary(string), do: MapSet.new()

  def extract_entities(format_string) do
    {_, entities} = format_for(format_string, nil)
    entities
  end

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

  defp maybe_format_for({:ok, pattern}, script, viewer) do
    {parts, entities} =
      Enum.reduce(pattern, {[], MapSet.new()}, fn
        {:format, code}, {parts, entities} ->
          case Scripting.eval(code, script: script) do
            {:ok, %Entity{} = entity} ->
              display = resolve_entity_name(entity, viewer)
              {[display | parts], MapSet.put(entities, entity)}

            {:ok, value} ->
              {[to_string(value) | parts], entities}

            {:error, error} ->
              {[inspect(error) | parts], entities}
          end

        plain, {parts, entities} ->
          {[plain | parts], entities}
      end)

    {parts |> Enum.reverse() |> Enum.join(), entities}
  end

  defp maybe_format_for({:error, _} = error, _script, _viewer) do
    {inspect(error), MapSet.new()}
  end

  # With no viewer, skip __namefor__ entirely — just use the name attribute.
  # This makes format_for(text, nil) safe for entity-discovery purposes.
  defp resolve_entity_name(entity, nil) do
    case Record.get_attribute(entity, "name") do
      name when is_binary(name) -> name
      _ -> inspect(entity)
    end
  end

  defp resolve_entity_name(entity, viewer) do
    case Method.call_entity(entity, "__namefor__", [viewer]) do
      result when is_binary(result) ->
        result

      _ ->
        case Record.get_attribute(entity, "name") do
          name when is_binary(name) -> name
          _ -> inspect(entity)
        end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Format.String{} = format_string, opts) do
      concat(["f", to_doc(format_string.string, opts)])
    end
  end
end
