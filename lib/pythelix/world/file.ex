defmodule Pythelix.World.File do
  alias Pythelix.Scripting.REPL
  alias Pythelix.World.File.State

  @pattern_entity ~r/^\[(.*?)\]$/
  @pattern_method ~r/^\{(.*?)\}$/

  def parse_file(path) do
    File.stream!(path)
    |> parse(path)
  end

  def parse_string(text) do
    String.split(text, "\n")
    |> parse("<string>")
  end

  defp parse(lines, path) do
    lines
    |> Enum.map(fn string ->
      string
      |> String.replace_trailing("\r\n", "\n")
      |> String.trim_trailing("\n")
    end)
    |> Enum.with_index()
    |> parse_lines(%State{})
    |> case do
      %{error: message} when message != nil ->
        {:error, message}

      %{entities: entities} ->
        entities = Enum.map(entities, &Map.put(&1, :file, path))

        {:ok, entities}
    end
  end

  defp parse_lines(_lines, state = %{error: message}) when message != nil do
    state
  end

  defp parse_lines([], state = %{current: current}) when current != nil do
    %{state | current: nil, entities: [set_entity(current) | state.entities]}
  end

  defp parse_lines([], state), do: state

  defp parse_lines([{line, index} | rest], state = %{multiline_key: key, current: current, need_more: true})
       when key != nil do
    text =
      [line | current.attributes[key]]
      |> Enum.reverse()
      |> Enum.join("\n")

    case REPL.parse(text) do
      :complete ->
        updated = put_in(current.attributes[key], text)
        parse_lines(rest, %{state | current: updated, multiline_key: nil, need_more: false})

      {:need_more, _} ->
        current = update_in(current.attributes[key], &[line | &1])

        parse_lines(rest, %{state | current: current})

      {:error, _} ->
        put_error(state, {line, index}, "Syntax error while reading a multiline attribute")
    end
  end

  defp parse_lines([{line, index} | rest], state = %{current: current, method_name: method, need_more: need_more}) do
    cond do
      need_more && (current != nil and method != nil) ->
        state = parse_method_content(state, {line, index})
        parse_lines(rest, state)

      !need_more && line =~ @pattern_method ->
        state = parse_method_name(state, {line, index})
        parse_lines(rest, state)

      !need_more && line =~ @pattern_entity ->
        state = parse_entity_key(state, line, index)
        parse_lines(rest, state)

      current != nil and method != nil ->
        state = parse_method_content(state, {line, index})
        parse_lines(rest, state)

      !need_more && String.contains?(line, ":") ->
        state = parse_attribute(state, {line, index})
        parse_lines(rest, state)

      String.trim(line) == "" ->
        parse_lines(rest, state)

      true ->
        put_error(state, {line, index}, "Syntax error")
    end
  end

  def parse_method_content(%{current: current} = state = %{method_name: method}, {line, index}) do
    text =
      [line | elem(state.current.methods[method], 1)]
      |> Enum.reverse()
      |> Enum.join("\n")

    case REPL.parse(text) do
      :complete ->
        current = update_in(current.methods[method], fn {cst, lines} -> {cst, [line | lines]} end)

        %{state | current: current, need_more: false}

      {:need_more, _} ->
        current = update_in(current.methods[method], fn {cst, lines} -> {cst, [line | lines]} end)

        %{state | current: current, need_more: true}

      {:error, _} ->
        put_error(state, {line, index}, "Syntax error while reading a method")
    end
  end

  defp parse_method_name(state, {line, index}) do
    current = state.current
    method_name = Regex.replace(@pattern_method, line, "\\1")

    cond do
      String.contains?(method_name, "(") ->
        case Pythelix.Command.Signature.constraints(method_name) do
          {name, constraints} when is_binary(name) ->
            put_in(current.methods[name], {constraints, []})
            |> then(& %{state | method_name: name, current: &1, need_more: true})

          error ->
            put_error(state, {line, index}, "Signature error: #{inspect(error)}")
        end

      true ->
        put_in(current.methods[method_name], {:free, []})
        |> then(& %{state | method_name: method_name, current: &1, need_more: true})
    end
  end

  defp parse_attribute(%{current: current} = state, {line, index}) do
    [key, val] = String.split(line, ":", parts: 2)
    key = String.trim(key)
    val = String.trim(val)

    case REPL.parse(val) do
      :complete ->
        current = put_in(current.attributes[key], val)

        %{state | current: current}

      {:need_more, _} ->
        current = put_in(current.attributes[key], [val])

        %{state | multiline_key: key, current: current, need_more: true}

      {:error, _} ->
        put_error(state, {line, index}, "Syntax error, invalid attribute value: {inspect(val)}")
    end
  end

  defp parse_entity_key(%{current: current} = state, line, index) do
    entities = state.entities

    entities = (current != nil && [set_entity(current) | entities]) || entities
    current = new_entity(index)
    key_name = Regex.replace(@pattern_entity, line, "\\1")
    current = put_in(current.key, key_name)

    %{state | entities: entities, current: current, multiline_key: nil, method_name: nil}
  end

  defp new_entity(index) do
    %{
      key: nil,
      line: index + 1,
      attributes: %{},
      methods: %{}
    }
  end

  defp set_entity(entity) do
    update_in(entity.methods, fn methods ->
      methods
      |> Enum.map(fn {name, {args, lines}} ->
        lines =
          lines
          |> Enum.reverse()
          |> Enum.join("\n")

        {name, {args, lines}}
      end)
      |> Map.new()
    end)
  end

  defp put_error(state, {line, index}, reason) do
    %{state | error: "line #{index + 1}\n#{reason}\n    #{line}"}
  end
end
