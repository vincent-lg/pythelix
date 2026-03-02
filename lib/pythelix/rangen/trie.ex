defmodule Pythelix.Rangen.Trie do
  @moduledoc """
  A pure map-based trie for tracking used string combinations.

  Each entry is a list of string parts. The trie structure uses nested maps
  with a `:leaf` key marking terminal nodes.

  Example: `["a", "b"]` is stored as `%{"a" => %{"b" => %{:leaf => true}}}`.
  """

  @type t :: map()

  @doc "Create a new empty trie."
  @spec new() :: t()
  def new, do: %{}

  @doc "Insert a list of string parts into the trie."
  @spec insert(t(), [String.t()]) :: t()
  def insert(trie, []), do: Map.put(trie, :leaf, true)

  def insert(trie, [part | rest]) do
    child = Map.get(trie, part, %{})
    Map.put(trie, part, insert(child, rest))
  end

  @doc "Remove a leaf entry from the trie. Returns the trie unchanged if the entry doesn't exist."
  @spec remove(t(), [String.t()]) :: t()
  def remove(trie, []) do
    Map.delete(trie, :leaf)
  end

  def remove(trie, [part | rest]) do
    case Map.get(trie, part) do
      nil ->
        trie

      child ->
        updated = remove(child, rest)

        if updated == %{} do
          Map.delete(trie, part)
        else
          Map.put(trie, part, updated)
        end
    end
  end

  @doc "Check if an exact part sequence exists in the trie (has a `:leaf` marker)."
  @spec used?(t(), [String.t()]) :: boolean()
  def used?(trie, []) do
    Map.get(trie, :leaf, false) == true
  end

  def used?(trie, [part | rest]) do
    case Map.get(trie, part) do
      nil -> false
      child -> used?(child, rest)
    end
  end

  @doc "Count total leaf entries in the trie."
  @spec count(t()) :: non_neg_integer()
  def count(trie) do
    leaf_count = if Map.get(trie, :leaf), do: 1, else: 0

    trie
    |> Enum.reduce(leaf_count, fn
      {:leaf, _}, acc -> acc
      {_key, child}, acc when is_map(child) -> acc + count(child)
      _, acc -> acc
    end)
  end
end
