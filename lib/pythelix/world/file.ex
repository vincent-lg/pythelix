defmodule Pythelix.World.File do
  defmodule Pythelix.Building.File.State do
    defstruct entities: [], current: nil, multiline_key: nil, method_name: nil, error: nil
  end

  alias Pythelix.Building.File.State

  @pattern_entity_or_method ~r/^(\[.*?\])|(\{.*?\})$/
  @pattern_entity ~r/^\[(.*?)\]$/
  @pattern_method ~r/^\{(.*?)\}$/

  def parse_file(path) do
    File.stream!(path)
    |> Enum.map(&String.trim_trailing(&1, "\n"))
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

  defp parse_lines([{line, _} | rest], state = %{multiline_key: key, current: current})
       when key != nil do
    cond do
      line == "\"\"\"" ->
        updated =
          update_in(current.attributes[key], fn lines ->
            lines
            |> Enum.reverse()
            |> Enum.join("\n")
          end)

        parse_lines(rest, %{state | current: updated, multiline_key: nil})

      true ->
        current = update_in(current.attributes[key], &[line | &1])

        parse_lines(rest, %{state | current: current})
    end
  end

  defp parse_lines([{line, index} | rest], state = %{current: current, method_name: method}) do
    cond do
      current != nil and method != nil and !(line =~ @pattern_entity_or_method) ->
        state = parse_method_content(state, {line, index})
        parse_lines(rest, state)

      line =~ @pattern_method ->
        state = parse_method_name(state, line)
        parse_lines(rest, state)

      String.contains?(line, ":") ->
        state = parse_attribute(state, line)
        parse_lines(rest, state)

      line =~ @pattern_entity ->
        state = parse_entity_key(state, line, index)
        parse_lines(rest, state)

      String.trim(line) == "" ->
        parse_lines(rest, state)

      true ->
        put_error(state, {line, index}, "Syntax error")
    end
  end

  def parse_method_content(state = %{method_name: method}, {line, index}) do
    cond do
      String.trim(line) == "" ->
        state

      String.starts_with?(line, " ") ->
        current = state.current
        current = update_in(current.methods[method], &[line | &1])

        %{state | current: current}

      true ->
        put_error(state, {line, index}, "Syntax error")
    end
  end

  defp parse_method_name(state, line) do
    current = state.current
    method_name = Regex.replace(@pattern_method, line, "\\1")
    current = put_in(current.methods[method_name], [])

    %{state | method_name: method_name, current: current}
  end

  defp parse_attribute(state, line) do
    [key, val] = String.split(line, ":", parts: 2)
    key = String.trim(key)
    val = String.trim(val)
    current = state.current

    cond do
      val == "\"\"\"" ->
        current = put_in(current.attributes[key], [])

        %{state | multiline_key: key, current: current}

      true ->
        current = put_in(current.attributes[key], val)

        %{state | current: current}
    end
  end

  defp parse_entity_key(state, line, index) do
    current = state.current
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
      |> Enum.map(fn {name, lines} ->
        lines =
          lines
          |> Enum.reverse()
          |> Enum.join("\n")

        {name, lines}
      end)
      |> Map.new()
    end)
  end

  defp put_error(state, {line, index}, reason) do
    %{state | error: "line #{index + 1}\n#{reason}\n    #{line}"}
  end
end
