defmodule Pythelix.Scripting.Format.String do
  @moduledoc """
  A string, ready to be formatted.

  Internally, an f-string is stored as a list of segments, where each segment
  is a `{template, variables}` tuple.  This preserves the variable snapshot
  taken at the point each f-string literal was created, even when f-strings
  are concatenated inside loops (where the same variable names take different
  values on each iteration).
  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Format.Spec
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Stackable

  @enforce_keys [:segments]
  defstruct [:segments]

  @typedoc """
  A formatted string (f-string).

  Each segment is a `{template, variables}` pair so that concatenated
  f-strings keep independent variable snapshots.
  """
  @type segment() :: {binary(), map()}
  @type t() :: %Format.String{segments: [segment()]}

  @spec new(Script.t(), binary()) :: t()
  def new(%Script{} = script, string) do
    variables = script.variables

    %Format.String{segments: [{string, variables}]}
  end

  @doc """
  Create a Format.String from a plain string (no variables).
  """
  @spec from_plain(binary()) :: t()
  def from_plain(string) when is_binary(string) do
    %Format.String{segments: [{string, %{}}]}
  end

  @doc """
  Concatenate two Format.Strings (or a mix of plain and format strings).
  """
  @spec concat(t(), t()) :: t()
  def concat(%Format.String{segments: a}, %Format.String{segments: b}) do
    %Format.String{segments: a ++ b}
  end

  def concat(%Format.String{segments: segs}, b) when is_binary(b) do
    %Format.String{segments: segs ++ [{b, %{}}]}
  end

  def concat(a, %Format.String{segments: segs}) when is_binary(a) do
    %Format.String{segments: [{a, %{}} | segs]}
  end

  @doc """
  Repeat an f-string n times.
  """
  @spec repeat(t(), non_neg_integer()) :: t()
  def repeat(%Format.String{segments: segs}, n) when is_integer(n) and n >= 0 do
    repeated = List.duplicate(segs, n) |> List.flatten()
    %Format.String{segments: repeated}
  end

  @doc """
  Return the raw template string (all segments joined).

  Used for display / inspection purposes only.
  """
  @spec template(t()) :: binary()
  def template(%Format.String{segments: segments}) do
    segments |> Enum.map(fn {s, _} -> s end) |> Enum.join()
  end

  @doc """
  Format the variables and return the formatted string.

  Args:

  * format (Format.String): the formatted string.
  """
  @spec format(Format.String.t()) :: String.t()
  def format(string) when is_binary(string), do: string

  def format(%Format.String{segments: segments}) do
    segments
    |> Enum.map(fn {string, variables} ->
      script = %Script{id: "format", bytecode: [], variables: variables, immediate: true}

      do_split(String.graphemes(string), [], "", :text)
      |> maybe_format(script)
    end)
    |> Enum.join()
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

  def format_for(%Format.String{segments: segments}, viewer) do
    {parts, entities} =
      Enum.reduce(segments, {[], MapSet.new()}, fn {string, variables}, {acc_parts, acc_entities} ->
        script = %Script{id: "format", bytecode: [], variables: variables, immediate: true}

        case do_split(String.graphemes(string), [], "", :text) do
          {:ok, _} = result ->
            {text, ents} = maybe_format_for(result, script, viewer)
            {[text | acc_parts], MapSet.union(acc_entities, ents)}

          {:error, _} = error ->
            {[Kernel.inspect(error) | acc_parts], acc_entities}
        end
      end)

    {parts |> Enum.reverse() |> Enum.join(), entities}
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
            Kernel.inspect(error)
        end

      plain ->
        plain
    end)
    |> Enum.join()
  end

  defp maybe_format({:error, _}, _script), do: ""

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

            {:ok, %Stackable{entity: entity, quantity: quantity}} ->
              display =
                entity
                |> apply_conversion_for(conv, script, viewer, quantity)
                |> format_with_spec(spec_str)

              {[display | parts], entities}

            {:ok, value} ->
              display =
                value
                |> apply_conversion(conv, script)
                |> format_with_spec(spec_str)

              {[display | parts], entities}

            {:error, error} ->
              {[Kernel.inspect(error) | parts], entities}
          end

        plain, {parts, entities} ->
          {[plain | parts], entities}
      end)

    {parts |> Enum.reverse() |> Enum.join(), entities}
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
      {:traceback, _} -> Kernel.inspect(value)
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

  # Quantity-aware conversions for stackables in format_for
  defp apply_conversion_for(entity, nil, _script, viewer, quantity),
    do: resolve_entity_name(entity, viewer, quantity)

  defp apply_conversion_for(entity, "c", _script, viewer, quantity),
    do: capitalize_first(resolve_entity_name(entity, viewer, quantity))

  defp apply_conversion_for(entity, conv, script, _viewer, _quantity),
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
      _ -> Kernel.inspect(entity)
    end
  end

  defp resolve_entity_name(entity, viewer) do
    case Method.call_entity(entity, "__namefor__", [viewer]) do
      result when is_binary(result) ->
        result

      _ ->
        case Record.get_attribute(entity, "name") do
          name when is_binary(name) -> name
          _ -> Kernel.inspect(entity)
        end
    end
  end

  # With no viewer, quantity is irrelevant — skip __namefor__ as usual.
  defp resolve_entity_name(entity, nil, _quantity),
    do: resolve_entity_name(entity, nil)

  # Inspects the __namefor__ method signature to decide whether to pass quantity:
  #   - 2+ positional args (excl. self) → call with [viewer, quantity]
  #   - 1 positional arg, or :free args  → call with [viewer] / [viewer, quantity]
  # Falls back to the name attribute if the hook is absent or errors.
  defp resolve_entity_name(entity, viewer, quantity) do
    result =
      case Record.get_method(entity, "__namefor__") do
        %Method{args: :free} ->
          Method.call_entity(entity, "__namefor__", [viewer, quantity])

        %Method{args: constraints} when is_list(constraints) ->
          positional_count =
            constraints
            |> Enum.reject(fn {name, _opts} -> name == "self" end)
            |> Enum.count(fn {_name, opts} -> opts[:index] != nil end)

          args = if positional_count >= 2, do: [viewer, quantity], else: [viewer]
          Method.call_entity(entity, "__namefor__", args)

        _ ->
          nil
      end

    case result do
      r when is_binary(r) ->
        r

      _ ->
        case Record.get_attribute(entity, "name") do
          name when is_binary(name) -> name
          _ -> Kernel.inspect(entity)
        end
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Format.String{} = format_string, opts) do
      concat(["f", to_doc(Format.String.template(format_string), opts)])
    end
  end
end
