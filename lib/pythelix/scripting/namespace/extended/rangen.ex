defmodule Pythelix.Scripting.Namespace.Extended.Rangen do
  @moduledoc """
  Module containing the extended methods for the rangen entity.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Rangen
  alias Pythelix.Record

  defmet generate(script, namespace), [] do
    entity = Store.get_value(namespace.self)
    patterns = Record.get_attribute(entity, "patterns")
    parsed = Rangen.parse_patterns(patterns)
    key = Entity.get_id_or_key(entity)

    Rangen.ensure_trie(key, parsed)
    snapshot = Rangen.get_trie(key)

    case do_generate(parsed, snapshot, entity, []) do
      {:ok, parts, _} ->
        result = Enum.join(parts, "")
        Rangen.add_entry(key, result, parts)
        {script, result}

      :exhausted ->
        {Script.raise(script, ValueError, "all combinations have been exhausted"), :none}
    end
  end

  defmet add(script, namespace), [
    {:string, index: 0, keyword: "string", type: :str}
  ] do
    entity = Store.get_value(namespace.self)
    patterns = Record.get_attribute(entity, "patterns")
    parsed = Rangen.parse_patterns(patterns)
    key = Entity.get_id_or_key(entity)

    Rangen.ensure_trie(key, parsed)
    parts = Rangen.decompose_string(namespace.string, parsed)
    Rangen.add_entry(key, namespace.string, parts)

    {script, :none}
  end

  defmet remove(script, namespace), [
    {:string, index: 0, keyword: "string", type: :str}
  ] do
    entity = Store.get_value(namespace.self)
    patterns = Record.get_attribute(entity, "patterns")
    parsed = Rangen.parse_patterns(patterns)
    key = Entity.get_id_or_key(entity)

    Rangen.ensure_trie(key, parsed)
    parts = Rangen.decompose_string(namespace.string, parsed)
    Rangen.remove_entry(key, namespace.string, parts)

    {script, :none}
  end

  defmet clear(script, namespace), [] do
    entity = Store.get_value(namespace.self)
    key = Entity.get_id_or_key(entity)
    Rangen.clear_entries(key)

    {script, :none}
  end

  @doc "Extended property for count."
  def count(_script, self) do
    entity = Store.get_value(self)
    patterns = Record.get_attribute(entity, "patterns")
    parsed = Rangen.parse_patterns(patterns)
    key = Entity.get_id_or_key(entity)

    Rangen.ensure_trie(key, parsed)
    Rangen.count(key)
  end

  # Recursive backtracking generator.
  # Tries each option (shuffled) at each position, checking the `check` method
  # at each step to prune invalid branches.
  defp do_generate([], trie, _entity, parts) do
    if Rangen.Trie.used?(trie, parts) do
      :exhausted
    else
      {:ok, parts, trie}
    end
  end

  defp do_generate([options | rest], trie, entity, parts) do
    shuffled = Enum.shuffle(options)

    Enum.reduce_while(shuffled, :exhausted, fn option, _acc ->
      candidate = parts ++ [option]
      text_so_far = Enum.join(candidate, "")

      if call_check(entity, text_so_far) do
        case do_generate(rest, trie, entity, candidate) do
          {:ok, _parts, _trie} = success -> {:halt, success}
          :exhausted -> {:cont, :exhausted}
        end
      else
        {:cont, :exhausted}
      end
    end)
  end

  defp call_check(entity, text) do
    case Method.call_entity(entity, "check", [text]) do
      :nomethod -> true
      :noresult -> true
      :traceback -> true
      result -> result == true
    end
  end
end
