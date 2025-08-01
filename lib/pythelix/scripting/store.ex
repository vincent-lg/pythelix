defmodule Pythelix.Scripting.Store do
  @moduledoc """
  A global store using ETS for the Pythello scripting language.
  """

  @script_table :script_store
  @entities_table :entities_table
  @reference_table :reference_store

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Object.{Attribute, Dict, Reference}
  alias Pythelix.Scripting.Protocol.ChildReferences
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.SubEntity

  @doc """
  Initializes the ETS table.
  Should be called once on application startup.
  """
  @spec init() :: :ok
  def init do
    clear()

    [@script_table, @entities_table, @reference_table]
    |> Enum.each(fn table ->
      if !Enum.member?(:ets.all(), table) do
        :ets.new(table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])
      end
    end)
  end

  def clear do
    [@script_table, @entities_table, @reference_table]
    |> Enum.each(fn table ->
      if Enum.member?(:ets.all(), table) do
        :ets.delete(table)
      end
    end)
  end

  @doc """
  Get the number of scripts in the ETS table.
  """
  def get_number_of_scripts() do
    :ets.info(@script_table, :size)
  end

  @doc """
  Get the number of references in the ETS table.
  """
  def get_number_of_references() do
    :ets.info(@reference_table, :size)
  end

  @doc """
  Get the memory usage of scripts in the ETS table.
  """
  def get_memory_of_scripts() do
    :ets.info(@script_table, :memory) * :erlang.system_info(:wordsize)
  end

  @doc """
  Get the memory usage of references in the ETS table.
  """
  def get_memory_of_references() do
    :ets.info(@reference_table, :memory) * :erlang.system_info(:wordsize)
  end

  @doc """
  Creates a new script reference.

  Returns the new reference UUID.
  """
  @spec new_script(String.t()) :: String.t()
  def new_script(reference \\ nil) do
    ref =
      case reference do
        nil -> generate_unique_uuid(@script_table)
        something -> something
      end

    :ets.insert(@script_table, {ref})
    ref
  end

  @doc """
  Creates a new reference with an owner ref.

  Returns the new reference UUID.
  """
  @spec new_reference(term(), String.t(), nil | Reference.t()) :: String.t()
  def new_reference(value, owner, parent \\ nil)

  def new_reference(%Entity{} = entity, owner, parent) do
    id_or_key = Entity.get_id_or_key(entity)

    case :ets.lookup(@entities_table, id_or_key) do
      [{^id_or_key, ref}] ->
        :ets.insert_new(@reference_table, {ref, entity, owner, parent})
        ref = %Reference{value: ref}
        update_child_references(ref, entity)
        ref

      _ ->
        ref = generate_unique_uuid(@reference_table)
        ref = %Reference{value: ref}
        :ets.insert(@entities_table, {id_or_key, ref.value})
        :ets.insert(@reference_table, {ref.value, entity, owner, parent})
        update_child_references(ref, entity)
        ref
    end
  end

  def new_reference(value, owner, parent) do
    if Script.references?(value) do
      generate_new_reference(value, owner, parent)
    else
      value
    end
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
  Return the list of script IDs.
  """
  @spec extract_scripts() :: [String.t()]
  def extract_scripts() do
    :ets.tab2list(:script_store)
  end

  @doc """
  Return the list of registered references and their values.
  """
  @spec extract_references() :: [{String.t(), term(), String.t(), Reference.t() | nil}]
  def extract_references() do
    :ets.tab2list(:reference_store)
  end

  @doc """
  Updates a reference's value.
  Returns `:ok` or `:error` if not found.
  """
  @spec update_reference(Reference.t() | term(), term()) :: :ok | :error
  def update_reference(%Reference{} = ref, new_value) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, _old_value, owner, parent}] ->
        :ets.insert(@reference_table, {ref.value, new_value, owner, parent})
        update_child_references(ref, new_value)
        {:ok, get_reference_ancestor!(ref)}

      _ ->
        :error
    end
    |> then(fn
      {:ok, {%Attribute{} = attribute, value}} ->
        id_or_key = Entity.get_id_or_key(attribute.entity)
        Record.set_attribute(id_or_key, attribute.attribute, value)

      :error ->
        :error

      _other ->
        :ok
    end)
  end

  def update_reference(_ref, _new_value), do: :ok

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
  Bind an entity attribute to a reference.
  """
  @spec bind_entity_attribute(Reference.t() | term(), Entity.t(), Stgring.t()) :: :ok
  def bind_entity_attribute(%Reference{} = reference, %Entity{} = entity, attribute) do
    update_reference_parent(reference, %Attribute{entity: entity, attribute: attribute})
    :ok
  end

  def bind_entity_attribute(_reference, %Entity{}, _attribute), do: :ok

  @doc """
  Get the bound reference associated with an entity attribute.
  """
  @spec get_bound_entity_attribute(Entity.t(), String.t()) :: Reference.t() | nil
  def get_bound_entity_attribute(%Entity{} = entity, name) do
    attribute = %Attribute{entity: entity, attribute: name}
    match_spec = [{{:"$1", :"$2", :"$3", attribute}, [], [:"$1"]}]
    case :ets.select(:reference_store, match_spec) do
      [reference] -> %Reference{value: reference}
      _ -> nil
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
  @spec insert_references([{String.t(), term(), String.t(), Reference.t() | nil}]) :: :ok
  def insert_references(references) when is_list(references) do
    :ets.insert(@reference_table, references)
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

  def get_reference_parent!(%Reference{} = ref) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, _value, _owner, parent}] -> parent
      _ -> raise inspect(ref)
    end
  end

  def get_reference_parent!(_ref), do: nil

  def get_reference_ancestor!(ref, seen \\ MapSet.new())

  def get_reference_ancestor!(%Reference{} = ref, seen) do
    if MapSet.member?(seen, ref.value) do
      {:loop, nil}
    else
      seen = MapSet.put(seen, ref.value)

      grand_parent = get_reference_parent!(ref)

      case grand_parent do
        %Attribute{} = attribute ->
          {attribute, get_value(ref)}

        %Reference{} ->
          get_reference_ancestor!(grand_parent, seen)

        nil ->
          {nil, nil}
      end
    end
  end

  def get_reference_ancestor!(_ref, _seen), do: {nil, nil}

  defp get_reference_value!(%Reference{} = ref) do
    value = ref.value

    case :ets.lookup(@reference_table, value) do
      [{^value, value, _owner, _parent}] -> value
      _ -> raise inspect(ref)
    end
  end

  defp reference_to_value(%SubEntity {} = sub_entity, references) do
    {data, references} = reference_to_value(sub_entity.data, references)
    {%{sub_entity | data: data}, references}
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
    ChildReferences.children(value)
    |> Enum.each(& update_reference_parent(&1, ref))
  end

  defp generate_new_reference(%Reference{} = ref, owner, parent) do
    ref = ref.value

    case :ets.lookup(@reference_table, ref) do
      [{^ref, _value, _owner, old_parent}] when parent == old_parent ->
        :already

      [{^ref, value, _owner, _parent}] ->
        :ets.insert(@reference_table, {ref, value, owner, parent})
        :ok

      _ ->
        :error
    end
  end

  defp generate_new_reference(value, owner, parent) do
    ref = %Reference{value: generate_unique_uuid(@reference_table)}
    :ets.insert(@reference_table, {ref.value, value, owner, parent})

    case add_inner_references(value, owner, ref) do
      {:replace, value} ->
        :ets.insert(@reference_table, {ref.value, value, owner, parent})

      _ ->
        :ok
    end

    update_child_references(ref, value)
    ref
  end

  defp add_inner_references(%SubEntity{} = sub_entity, owner, parent) do
    dict = new_reference(sub_entity.data, owner, parent)

    {:replace, %{sub_entity | data: dict}}
  end

  defp add_inner_references(%Dict{} = dict, owner, ref) do
    new_dict =
      Dict.items(dict)
      |> Enum.reduce(Dict.new(), fn {key, value}, new_dict ->
        key = new_reference(key, owner, ref)
        value = new_reference(value, owner, ref)
        Dict.put(new_dict, key, value)
      end)

    {:replace, new_dict}
  end

  defp add_inner_references(%MapSet{} = set, owner, ref) do
    new_set =
      MapSet.to_list(set)
      |> Enum.reduce(MapSet.new(), fn value, new_set ->
        value = new_reference(value, owner, ref)
        MapSet.put(new_set, value)
      end)

    {:replace, new_set}
  end

  defp add_inner_references(list, owner, ref) when is_list(list) do
    new_list =
      list
      |> Enum.reduce([], fn value, new_list ->
        value = new_reference(value, owner, ref)
        [value | new_list]
      end)
      |> Enum.reverse()

    {:replace, new_list}
  end

  defp add_inner_references(_value, _owner, _parent), do: :noneed
end
