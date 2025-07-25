defmodule Pythelix.Scripting.Object.Dict do
  @moduledoc """
  A simple ordered dictionary, preserving insertion order while offering fast lookup.

  This is mostly used by Pythelo, the Pythelix scripting language,
  to handle Pythnon-like dictionaries.

  In terms of mechanism, each entry is stored as `{key_id, value}`
  internally, and ordering is preserved. The collection is lightweight
  and efficient, but its memory footprint is greater than a map. Inserting
  new keys, removing existing keys and updating existing keys usually is O(1),
  though getting keys, items or values is O(n) (like it is in Python).

  Memory-wise, an empty `Dict` takes around 90 bytes (against 10 for a map).
  When the dictionary contains 10 entries, it is twice as heavy as a map
  with 10 entries. As the dict increases in size, the distance between
  them will fade in proportion to their respective size, though a map
  will always need less memory (if only a few bytes per entry).

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, :a, 10)
      iex> dict = Dict.put(dict, :b, 20)
      iex> dict = Dict.put(dict, :c, 30)
      iex> Dict.get(dict, :b)
      20
      iex> Dict.keys(dict)
      [:a, :b, :c]
      iex> Dict.values(dict)
      [10, 20, 30]
      iex> Dict.items(dict)
      [a: 10, b: 20, c: 30]
      iex> dict = Dict.delete(dict, :b)
      iex> Dict.items(dict)
      [a: 10, c: 30]
  """

  alias Pythelix.Scripting.Object.{Dict, Reference}

  defstruct entries: %{}, key_id: 0

  @type t :: %Dict{
          entries: %{any() => {non_neg_integer(), any()}},
          key_id: non_neg_integer()
        }

  @doc """
  Creates a new empty Dict.

  ## Examples

      iex> Dict.new()

      iex> dict = Dict.new(%{"a" => 8, "k" => -3, "c" => 12})
      iex> length(Dict.keys(dict))
      3

  """
  @spec new(map() | t()) :: t()
  def new(map \\ %{})

  def new(%Dict{} = dict) do
    Enum.reduce(Dict.items(dict), %Dict{}, fn {key, value}, dict ->
      Dict.put(dict, key, value)
    end)
  end

  def new(map) when is_map(map) do
    Enum.reduce(map, %Dict{}, fn {key, value}, dict ->
      Dict.put(dict, key, value)
    end)
  end

  def new(list) when is_list(list) do
    Enum.reduce(list, %Dict{}, fn {key, value}, dict ->
      Dict.put(dict, key, value)
    end)
  end

  @doc """
  Gets the value for a given key, retuning `default` if not present.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> Dict.get(dict, "my key")
      35
      iex> Dict.get(dict, "nonexistent key")
      nil
      iex> Dict.get(dict, "nonexistent key", :no_key)
      :no_key
  """
  @spec get(t(), term(), term()) :: term
  def get(%Dict{entries: entries}, key, default \\ nil) do
    Map.get(entries, key, default)
    |> then(fn
      {id, value} when is_integer(id) -> value
      other -> other
    end)
  end

  @doc """
  Inserts or updates a key with the given value.

  If the key is present, override the value. If not, add the value.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> Dict.get(dict, "my key")
      35
      iex> dict = Dict.put(dict, "my key", "something")
      iex> Dict.get(dict, "my key")
      "something"
  """
  @spec put(t(), term(), term()) :: t()
  def put(%Dict{entries: entries} = dict, key, value) do
    Map.get_and_update(entries, key, fn
      nil -> {dict.key_id, {dict.key_id, value}}
      {id, _} -> {nil, {id, value}}
    end)
    |> then(fn
      {nil, map} -> %{dict | entries: map}
      {new_id, map} -> %{dict | entries: map, key_id: new_id + 1}
    end)
  end

  @doc """
  Deletes a key from the dictionary.

  Args:

  - `key`: the key to remove.

  If the key does not exist, returns map unchanged.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> Dict.get(dict, "my key")
      35
      iex> dict = Dict.delete(dict, "my key")
      iex> Dict.get(dict, "my key")
      nil
  """
  @spec delete(t(), term()) :: t()
  def delete(%Dict{} = dict, key) do
    %Dict{dict | entries: Map.delete(dict.entries, key)}
  end

  @doc """
  Deletes a key from the dictionary and return its value with the new dictionary.

  Args:

  - `key`: the key to remove.
  - `default`: the default value to return if the key doesn't exist (default `nil`).

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> Dict.get(dict, "my key")
      35
      iex> {value, dict} = Dict.pop(dict, "my key")
      iex> value
      35
      iex> Dict.get(dict, "my key")
      nil

      iex> dict = Dict.new()
      iex> {value, _dict} = Dict.pop(dict, "another key")
      iex> value
      nil

      iex> dict = Dict.new()
      iex> {value, _dict} = Dict.pop(dict, "another key", :unset)
      iex> value
      :unset
  """
  @spec pop(t(), term(), term()) :: {term(), t()}
  def pop(%Dict{} = dict, key, default \\ nil) do
    {value, entries} = Map.pop(dict.entries, key, default)

    case value do
      ^default -> {value, %Dict{dict | entries: entries}}
      {_key_id, new_value} -> {new_value, %Dict{dict | entries: entries}}
    end
  end

  @doc """
  Pop the last inserted item, removing it from the dictionary.
  Returns `:empty` if the dictionary is empty or `{key, value, dict}`
  if the dictionary is not empty. The last inserted key is removed first.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "first", 1)
      iex> dict = Dict.put(dict, "second", 2)
      iex> {key, value, dict} = Dict.popitem(dict)
      iex> {key, value}
      {"second", 2}
      iex> Dict.keys(dict)
      ["first"]

      iex> dict = Dict.new()
      iex> Dict.popitem(dict)
      :empty
  """
  @spec popitem(t()) :: :empty | {Sring.t(), String.t(), t()}
  def popitem(%Dict{entries: entries} = dict) do
    if map_size(entries) == 0 do
      :empty
    else
      entries
      |> Enum.sort_by(fn {_k, {id, _v}} -> id end, :desc)
      |> then(fn [{k, {_id, v}} | rest] -> {k, v, %{dict | entries: rest}} end)
    end
  end

  @doc """
  Returns the list of keys, in insertion order.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> dict = Dict.put(dict, "my second key", "something")
      iex> Dict.keys(dict)
      ["my key", "my second key"]
  """
  @spec keys(t()) :: [term()]
  def keys(%Dict{entries: entries}) do
    entries
    |> Enum.sort_by(fn {_k, {id, _v}} -> id end)
    |> Enum.map(fn {k, _} -> k end)
  end

  @doc """
  Returns the list of values, in insertion order.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> dict = Dict.put(dict, "my second key", "something")
      iex> Dict.values(dict)
      [35, "something"]
  """
  @spec values(t()) :: [term()]
  def values(%Dict{entries: entries}) do
    entries
    |> Enum.sort_by(fn {_k, {id, _v}} -> id end)
    |> Enum.map(fn {_k, {_id, v}} -> v end)
  end

  @doc """
  Returns the list of {key, value} pairs in insertion order.

  ## Examples

      iex> dict = Dict.new()
      iex> dict = Dict.put(dict, "my key", 35)
      iex> dict = Dict.put(dict, "my second key", "something")
      iex> Dict.items(dict)
      [{"my key", 35}, {"my second key", "something"}]
  """
  @spec items(t()) :: [{term(), term()}]
  def items(%Dict{entries: entries}) do
    entries
    |> Enum.sort_by(fn {_k, {id, _v}} -> id end)
    |> Enum.map(fn {k, {_id, v}} -> {k, v} end)
  end

  @doc """
  Update a dictionary based on a given dictionary.

  The keys and values in the new dictionary will override the former
  dictionary.

  ## Examples

      iex> dict1 = Dict.new()
      iex> dict1 = Dict.put(dict1, "my key", 35)
      iex> dict1 = Dict.put(dict1, "my second key", "something")
      iex> dict2 = Dict.new()
      iex> dict2 = Dict.put(dict2, "my key", 12)
      iex> dict2 = Dict.put(dict2, "my third key", -5)
      iex> dict = Dict.update(dict1, dict2)
      iex> Dict.items(dict)
      [{"my key", 12}, {"my second key", "something"}, {"my third key", -5}]
  """
  @spec update(t(), t()) :: t()
  def update(dict1, dict2) do
    Enum.reduce(Dict.items(dict2), dict1, fn {key, value}, dict ->
      Dict.put(dict, key, value)
    end)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Dict{entries: entries}, opts) do
      entries =
        entries
        |> Enum.sort_by(fn {_k, {id, _v}} -> id end)
        |> Enum.map(fn {k, {_id, v}} ->
          concat([
            Inspect.inspect(k, opts),
            ": ",
            Inspect.inspect(v, opts)
          ])
        end)

      entries =
        entries
        |> fold_doc(fn doc, acc -> concat([doc, ", ", acc]) end)

      concat(["{", entries, "}"])
    end
  end

  defimpl Pythelix.Scripting.Protocol.ChildReferences do
    def children(dict) do
      Dict.items(dict)
      |> Enum.reduce([], fn
        {%Reference{} = key, %Reference{} = value}, acc ->
          [[key, value] | acc]

        {%Reference{} = key, _}, acc ->
          [key | acc]

        {_, %Reference{} = value}, acc ->
          [value | acc]

        _, acc ->
          acc
      end)
    end
  end
end
