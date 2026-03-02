defmodule Pythelix.Rangen.TrieServer do
  @moduledoc """
  Agent holding an in-memory trie for one rangen generator key.

  One TrieServer is started per generator key, supervised under
  `Pythelix.Rangen.Supervisor` and named via `Pythelix.Rangen.Registry`.
  This avoids copying the full trie structure through ETS on every operation.
  """

  use Agent

  alias Pythelix.Rangen.Trie

  # --- Supervision -----------------------------------------------------------

  @doc "Start a TrieServer for the given key with an initial trie."
  def start(key, trie \\ Trie.new()) do
    DynamicSupervisor.start_child(
      Pythelix.Rangen.Supervisor,
      {__MODULE__, {key, trie}}
    )
  end

  @doc false
  def start_link({key, trie}) do
    Agent.start_link(fn -> trie end, name: via(key))
  end

  # --- Query -----------------------------------------------------------------

  @doc "Return true if an agent for this key is running."
  def alive?(key) do
    Registry.lookup(Pythelix.Rangen.Registry, key) != []
  end

  @doc "Return a snapshot of the trie (copied to caller's heap)."
  def get(key) do
    Agent.get(via(key), & &1)
  end

  @doc "Return the number of leaf entries without copying the trie."
  def count(key) do
    Agent.get(via(key), &Trie.count/1)
  end

  # --- Mutation --------------------------------------------------------------

  @doc "Insert parts into the trie in-place."
  def insert(key, parts) do
    Agent.update(via(key), &Trie.insert(&1, parts))
  end

  @doc "Remove parts from the trie in-place."
  def remove(key, parts) do
    Agent.update(via(key), &Trie.remove(&1, parts))
  end

  @doc "Replace the trie with an empty one."
  def reset(key) do
    Agent.update(via(key), fn _ -> Trie.new() end)
  end

  # ---------------------------------------------------------------------------

  defp via(key), do: {:via, Registry, {Pythelix.Rangen.Registry, key}}
end
