defmodule Pythelix.Scripting.Format.String do
  @moduledoc """
  A string, ready to be formatted.
  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Format.Spec
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
    |> process_segments()
    |> Enum.map(fn
      {:format, code, conv, spec_str} ->
        case Scripting.eval(code, script: script) do
          {:ok, value} ->
            value
            |> apply_conversion(conv, script)
            |> format_with_spec(spec_str)

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
      pattern
      |> process_segments()
      |> Enum.reduce({[], MapSet.new()}, fn
        {:format, code, conv, spec_str}, {parts, entities} ->
          case Scripting.eval(code, script: script) do
            {:ok, %Entity{} = entity} ->
              display =
                entity
                |> apply_conversion_for(conv, script, viewer)
                |> format_with_spec(spec_str)

              {[display | parts], MapSet.put(entities, entity)}

            {:ok, value} ->
              display =
                value
                |> apply_conversion(conv, script)
                |> format_with_spec(spec_str)

              {[display | parts], entities}

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

  # --- Expression splitting (extract conversion and format spec) ---

  defp process_segments(segments) do
    Enum.map(segments, fn
      {:format, raw} ->
        {expr, conv, spec} = split_expression(raw)
        {:format, expr, conv, spec}

      plain ->
        plain
    end)
  end

  @conversions ~w(r s c)

  @doc false
  def split_expression(content) do
    {expr_conv, spec} = split_at_spec(content)
    {expr, conv} = split_at_conversion(expr_conv)
    {expr, conv, spec}
  end

  defp split_at_spec(content) do
    graphemes = String.graphemes(content)

    case find_spec_pos(graphemes, 0, 0, :normal) do
      nil -> {content, nil}
      pos -> {String.slice(content, 0, pos), String.slice(content, (pos + 1)..-1//1)}
    end
  end

  # Scan left-to-right for the first `:` at bracket depth 0, outside string literals.
  defp find_spec_pos([], _pos, _depth, _state), do: nil

  # Inside string literals: handle escapes
  defp find_spec_pos(["\\" | [_ | rest]], pos, depth, state) when state in [:sq, :dq] do
    find_spec_pos(rest, pos + 2, depth, state)
  end

  defp find_spec_pos(["'" | rest], pos, depth, :sq),
    do: find_spec_pos(rest, pos + 1, depth, :normal)

  defp find_spec_pos(["\"" | rest], pos, depth, :dq),
    do: find_spec_pos(rest, pos + 1, depth, :normal)

  defp find_spec_pos([_ | rest], pos, depth, state) when state in [:sq, :dq],
    do: find_spec_pos(rest, pos + 1, depth, state)

  # Enter string literals
  defp find_spec_pos(["'" | rest], pos, depth, :normal),
    do: find_spec_pos(rest, pos + 1, depth, :sq)

  defp find_spec_pos(["\"" | rest], pos, depth, :normal),
    do: find_spec_pos(rest, pos + 1, depth, :dq)

  # Bracket depth
  defp find_spec_pos([c | rest], pos, depth, :normal) when c in ["(", "["],
    do: find_spec_pos(rest, pos + 1, depth + 1, :normal)

  defp find_spec_pos([c | rest], pos, depth, :normal) when c in [")", "]"],
    do: find_spec_pos(rest, pos + 1, max(depth - 1, 0), :normal)

  # Found `:` at depth 0
  defp find_spec_pos([":" | _rest], pos, 0, :normal), do: pos

  defp find_spec_pos([_ | rest], pos, depth, :normal),
    do: find_spec_pos(rest, pos + 1, depth, :normal)

  defp split_at_conversion(expr) do
    len = String.length(expr)

    if len >= 2 do
      conv_char = String.at(expr, len - 1)
      bang = String.at(expr, len - 2)

      if bang == "!" and conv_char in @conversions do
        {String.slice(expr, 0, len - 2), conv_char}
      else
        {expr, nil}
      end
    else
      {expr, nil}
    end
  end

  # --- Conversions ---

  defp apply_conversion(value, nil, _script), do: value

  defp apply_conversion(value, "r", script) do
    case Display.repr(script, value) do
      {:traceback, _} -> inspect(value)
      result -> result
    end
  end

  defp apply_conversion(value, "s", script) do
    case Display.str(script, value) do
      {:traceback, _} -> to_string(value)
      result -> result
    end
  end

  defp apply_conversion(value, "c", _script) do
    capitalize_first(to_string(value))
  end

  # Entity-aware conversions for format_for
  defp apply_conversion_for(entity, nil, _script, viewer),
    do: resolve_entity_name(entity, viewer)

  defp apply_conversion_for(entity, "c", _script, viewer),
    do: capitalize_first(resolve_entity_name(entity, viewer))

  defp apply_conversion_for(entity, conv, script, _viewer),
    do: apply_conversion(entity, conv, script)

  # --- Format spec application ---

  defp format_with_spec(value, nil), do: to_string(value)

  defp format_with_spec(value, spec_str) do
    case Spec.parse(spec_str) do
      {:ok, nil} -> to_string(value)
      {:ok, spec} -> Spec.apply(value, spec)
      {:error, _} -> to_string(value)
    end
  end

  defp capitalize_first(""), do: ""

  defp capitalize_first(str) do
    {first, rest} = String.split_at(str, 1)
    String.upcase(first) <> rest
  end

  # --- Entity name resolution ---

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
