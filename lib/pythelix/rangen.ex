defmodule Pythelix.Rangen do
  @moduledoc """
  Context module for the random string generator (Rangen).

  Each generator key gets one TrieServer (Agent) that holds its trie in
  process memory, avoiding ETS term-copying on every operation.

  The trie is built lazily on first access: raw strings loaded during
  `warmup/0` are stored in Cachex until `ensure_trie/2` is called with
  the entity's patterns.
  """

  import Ecto.Query, warn: false

  alias Pythelix.Repo
  alias Pythelix.Record.RangenEntry
  alias Pythelix.Rangen.Trie
  alias Pythelix.Rangen.TrieServer

  @doc """
  Load all rangen entries from the database and store raw strings in Cachex.

  Called during `Record.warmup/0`. Patterns are not available yet at this
  point, so raw strings are stored under `{:rangen_raw, key}` and consumed
  lazily by `ensure_trie/2`.
  """
  def warmup do
    entries = Repo.all(from e in RangenEntry, select: {e.generator_key, e.value})

    entries
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.each(fn {key, values} ->
      Cachex.put(:px_cache, {:rangen_raw, key}, values)
    end)

    :ok
  end

  @doc """
  Ensure a TrieServer is running for the given key.

  If none exists yet, builds the initial trie from any raw entries stored
  by `warmup/0` using the provided parsed patterns, then starts the server.
  Concurrent calls race harmlessly: the second start is silently ignored.
  """
  def ensure_trie(key, parsed_patterns) do
    unless TrieServer.alive?(key) do
      raw =
        case Cachex.get(:px_cache, {:rangen_raw, key}) do
          {:ok, nil} -> []
          {:ok, values} -> values
        end

      initial_trie = build_trie_from_raw(raw, parsed_patterns)

      case TrieServer.start(key, initial_trie) do
        {:ok, _} ->
          Cachex.del(:px_cache, {:rangen_raw, key})

        {:error, {:already_started, _}} ->
          # Lost the race — another caller started the server first; harmless
          :ok
      end
    end

    :ok
  end

  @doc "Return a snapshot of the trie for the given key (for backtracking)."
  def get_trie(key) do
    TrieServer.get(key)
  end

  @doc "Insert a new entry into both the DB and the trie."
  def add_entry(key, value, parts) do
    changeset = RangenEntry.changeset(%RangenEntry{}, %{generator_key: key, value: value})
    Repo.insert!(changeset)
    TrieServer.insert(key, parts)
    :ok
  end

  @doc "Remove an entry from both the DB and the trie."
  def remove_entry(key, value, parts) do
    query =
      from e in RangenEntry,
        where: e.generator_key == ^key and e.value == ^value

    Repo.delete_all(query)
    TrieServer.remove(key, parts)
    :ok
  end

  @doc "Clear all entries for a key from the DB and reset the trie."
  def clear_entries(key) do
    query = from e in RangenEntry, where: e.generator_key == ^key
    Repo.delete_all(query)
    Cachex.del(:px_cache, {:rangen_raw, key})

    if TrieServer.alive?(key) do
      TrieServer.reset(key)
    end

    :ok
  end

  @doc "Return the count of entries for the given key."
  def count(key) do
    TrieServer.count(key)
  end

  @doc """
  Parse a patterns attribute (list of strings) into a list of option lists.

  Each pattern string contains the possible characters for that position.
  For example, `["ab", "cd"]` → `[["a", "b"], ["c", "d"]]`.
  """
  def parse_patterns(patterns) do
    Enum.map(patterns, &String.graphemes/1)
  end

  @doc """
  Decompose a string into parts based on patterns (one character per position).
  """
  def decompose_string(string, patterns) do
    patterns
    |> Enum.reduce({[], string}, fn _pattern, {parts, remaining} ->
      if remaining == "" do
        {parts, ""}
      else
        {char, rest} = String.split_at(remaining, 1)
        {parts ++ [char], rest}
      end
    end)
    |> elem(0)
  end

  defp build_trie_from_raw(values, parsed_patterns) do
    Enum.reduce(values, Trie.new(), fn value, trie ->
      parts =
        if parsed_patterns != [] do
          decompose_string(value, parsed_patterns)
        else
          String.graphemes(value)
        end

      Trie.insert(trie, parts)
    end)
  end
end
