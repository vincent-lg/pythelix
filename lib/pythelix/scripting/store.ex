defmodule Pythelix.Scripting.Store do
  @moduledoc """
  A global store using ETS for the Pythello scripting language.
  """

  @script_table :script_store
  @entities_table :entities_table
  @reference_table :reference_store

  alias Pythelix.Entity
  alias Pythelix.Scripting.Object.{Dict, Reference}

  @doc """
  Initializes the ETS table.
  Should be called once on application startup.
  """
  @spec init() :: :ok
  def init do
    [@script_table, @entities_table, @reference_table]
    |> Enum.each(fn table ->
      :ets.new(table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])
    end)
  end

  @doc """
  Creates a new script reference.

  Returns the new reference UUID.
  """
  @spec new_script() :: String.t()
  def new_script() do
    ref = generate_unique_uuid(@script_table)
    :ets.insert(@script_table, {ref})
    ref
  end

  @doc """
  Creates a new reference with an owner ref.

  Returns the new reference UUID.
  """
  @spec new_reference(term(), String.t()) :: String.t()
  def new_reference(%Entity{} = entity, owner) do
    id_or_key = Entity.get_id_or_key(entity)

    case :ets.lookup(@entities_table, id_or_key) do
      [{^id_or_key, ref}] ->
        :ets.insert(@reference_table, {ref, entity, owner, nil})
        ref = %Reference{value: ref}
        update_child_references(ref, entity)
        ref

      _ ->
        ref = generate_unique_uuid(@reference_table)
        ref = %Reference{value: ref}
        :ets.insert(@entities_table, {id_or_key, ref.value})
        :ets.insert(@reference_table, {ref.value, entity, owner, nil})
        update_child_references(ref, entity)
        ref
    end
  end

  def new_reference(value, owner) do
    ref = generate_unique_uuid(@reference_table)
    ref = %Reference{value: ref}
    :ets.insert(@reference_table, {ref.value, value, owner, nil})
    update_child_references(ref, value)
    ref
  end

  @doc """
  Gets the value from a reference or value.
  """
  @spec get_value(term(), Keyword.t()) :: term()
  def get_value(reference, opts \\ [])

  def get_value(%Reference{} = reference, opts) do
    get_reference_value!(reference)
    |> then(fn value ->
      if Keyword.get(opts, :recursive, true) do
        reference_to_value(value, MapSet.new([reference]))
        |> then(fn {value, _} -> value end)
      else
        value
      end
    end)
  end

  def get_value(other, _opts), do: other

  @doc """
  Updates a reference's value.
  Returns `:ok` or `:error` if not found.
  """
  @spec update_reference(Reference.t(), term()) :: :ok | :error
  def update_reference(ref, new_value) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, _old_value, owner, parent}] ->
        :ets.insert(@reference_table, {ref.value, new_value, owner, parent})
        update_child_references(ref, new_value)
        :ok

      _ ->
        :error
    end
  end

  @doc """
  Updates a reference's parent.
  Returns `:ok` or `:error` if not found.
  """
  @spec update_reference_parent(Reference.t(), nil | Reference.t()) :: :ok | :error
  def update_reference_parent(ref, parent) do
    ref = ref.value

    case :ets.lookup(@reference_table, ref) do
      [{^ref, _value, _owner, old_parent}] when parent == old_parent ->
        :already

      [{^ref, value, owner, _parent}] ->
        :ets.insert(@reference_table, {ref, value, owner, parent})
        :ok

      _ ->
        :error
    end
  end

  @doc """
  Deletes a specific script.
  """
  @spec delete_script(String.t()) :: :ok
  def delete_script(ref) do
    :ets.delete(@script_table, ref)
    :ok
  end

  @doc """
  Deletes a specific reference.
  """
  @spec delete_reference(String.t()) :: :ok
  def delete_reference(%Reference{} = ref) do
    :ets.delete(@reference_table, ref.value)
    :ok
  end

  @doc """
  Deletes all references belonging to a specific owner (e.g., script ID).
  """
  @spec delete_by_owner(String.t()) :: {:ok, integer()}
  def delete_by_owner(owner) do
    match_spec = [{{:"$1", :"$2", owner, :"$4"}, [], [true]}]
    count = :ets.select_delete(@reference_table, match_spec)

    {:ok, count}
  end

  @doc """
  Bulk insert (used when rehydrating from disk).
  Accepts a list of {ref, value, owner_id}.
  """
  @spec insert_references(list) :: :ok
  def insert_references(entries) when is_list(entries) do
    :ets.insert(@reference_table, entries)
    :ok
  end

  defp generate_unique_uuid(table) do
    Stream.repeatedly(&UUID.uuid4/0)
    |> Stream.take(100)
    |> Enum.find(fn id -> not :ets.member(table, id) end)
    |> case do
      nil -> raise "Could not generate a unique UUID after 100 attempts"
      id -> id
    end
  end

  defp get_reference_parent!(%Reference{} = ref) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, _value, _owner, parent}] -> parent
      _ -> raise inspect(ref)
    end
  end

  defp get_reference_value!(%Reference{} = ref) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, value, _owner, _parent}] -> value
      _ -> raise inspect(ref)
    end
  end

  defp reference_to_value(%Reference{} = value, references) do
    if MapSet.member?(references, value) do
      {:ellipsis, references}
    else
      get_reference_value!(value)
      |> reference_to_value(MapSet.put(references, value))
    end
  end

  defp reference_to_value(value, references) when is_list(value) do
    Enum.reduce(value, {[], references}, fn element, {list, references} ->
      {element, references} = reference_to_value(element, references)
      {[element | list], references}
    end)
    |> then(fn {list, references} -> {Enum.reverse(list), references} end)
  end

  defp reference_to_value(%Dict{} = value, references) do
    Dict.items(value)
    |> Enum.reduce({Dict.new(), references}, fn {key, value}, {dict, references} ->
      {key, references} = reference_to_value(key, references)
      {value, references} = reference_to_value(value, references)

      {Dict.put(dict, key, value), references}
    end)
  end

  defp reference_to_value(%MapSet{} = value, references) do
    Enum.to_list(value)
    |> reference_to_value(references)
    |> then(fn {values, references} -> {MapSet.new(values), references} end)
  end

  defp reference_to_value(value, references), do: {value, references}

  defp update_child_references(ref, value) do
    Pythelix.Scripting.Protocol.ChildReferences.children(value)
    |> Enum.each(& update_reference_parent(&1, ref))
  end
end
