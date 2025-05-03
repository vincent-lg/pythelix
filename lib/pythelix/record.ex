defmodule Pythelix.Record do
  @moduledoc """
  The record context, to manipulate entities in the database.
  """

  import Ecto.Query, warn: false
  alias Pythelix.Repo
  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Record.Cache

  @doc """
  Gets a single entity and returns it, `nil` if it doesn't exist.

  ## Examples

      iex> get_entity(123)
      %Entity{}

      iex> get_entity(456)
      nil

  """
  def get_entity(:virtual), do: nil

  def get_entity(key) when is_binary(key) do
    case Cache.get_cached_entity(key) do
      nil ->
        case Repo.get_by(Record.Key, key: key) do
          nil -> nil
          %Record.Key{entity_id: entity_id} -> get_entity(entity_id)
        end

      entity ->
        entity
    end
  end

  def get_entity(id) when is_integer(id) do
    case Cache.get_cached_entity(id) do
      nil ->
        entity_with_key =
          Repo.one(
            from e in Record.Entity,
              left_join: ek in Record.Key,
              on: ek.entity_id == e.id,
              where: e.id == ^id,
              select: %{entity: e, key: ek.key}
          )

        case entity_with_key do
          nil ->
            nil

          %{entity: entity, key: key} ->
            entity =
              entity
              |> Repo.preload([:attributes, :methods])
              |> Cache.cache_stored_entity_attributes()
              |> Cache.cache_stored_entity_methods()
              |> Entity.new(key)
              |> Cache.cache_entity()

            entity
        end

      entity ->
        entity
    end
  end

  @doc """
  Gets the children from an entity.

  Returns a list of entities (children). If no child exists for this parent entity, returns an empty list.

  Args:

    * parent (entity): the parent entity.

  """
  @spec get_children(Entity.t()) :: [Entity.t()]
  def get_children(%Entity{} = parent) do
    parent
    |> Entity.get_id_or_key()
    |> Cache.get_children_id_or_key()
    |> Enum.map(&get_entity/1)
  end

  @doc """
  Gets the ancestor from an entity.

  Returns a list of entities (ancestors). If no child exists for this parent entity, returns an empty list.

  Args:

    * entity (entity): the child entity.

  """
  @spec get_ancestors(Entity.t()) :: [Entity.t()]
  def get_ancestors(%Entity{} = entity) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_ancestors_id_or_key()
    |> Enum.map(&get_entity/1)
  end

  @doc """
  Creates an entity.

  ## Examples

      iex> create_entity(%{field: value})
      {:ok, %Entity{}}

      iex> create_entity(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_entity(opts \\ []) do
    case opts[:virtual] do
      nil -> create_stored_entity(opts)
      _ -> create_virtual_entity(opts)
    end
    |> maybe_build_entity()
  end

  defp create_virtual_entity(opts) do
    parent_id = (opts[:parent] && opts[:parent].key) || nil
    location_id = (opts[:location] && opts[:location].key) || nil

    entity =
      %Entity{
        id: :virtual,
        key: opts[:key],
        parent_id: parent_id,
        location_id: location_id,
        attributes: %{},
        methods: %{}
      }

    {:ok, entity}
  end

  defp create_stored_entity(opts) do
    parent_id = (opts[:parent] && opts[:parent].id) || nil
    location_id = (opts[:location] && opts[:location].id) || nil

    Repo.transaction(fn ->
      # Check if the key is present and unique
      if opts[:key] do
        case Repo.get_by(Record.Key, key: opts[:key]) do
          nil -> :ok
          _ -> Repo.rollback("Key already exists")
        end
      end

      # Create the entity
      attrs = %{location_id: location_id, parent_id: parent_id}

      entity_changeset =
        %Record.Entity{}
        |> Record.Entity.changeset(attrs)

      case Repo.insert(entity_changeset) do
        {:ok, entity} ->
          # If a key is provided, create the associated key record
          if opts[:key] do
            key_changeset =
              %Record.Key{}
              |> Record.Key.changeset(%{key: opts[:key], entity_id: entity.id})

            case Repo.insert(key_changeset) do
              {:ok, _entity_key} -> entity
              {:error, changeset} -> Repo.rollback(changeset)
            end
          else
            entity
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, entity} ->
        entity = Entity.new(entity, opts[:key])

        {:ok, entity}

      other ->
        other
    end
  end

  @doc """
  Change the parent of the specified entity.

  Check that this would not create cclical relations

  Args:

  * entity (entity): the entity whose parent is to change.
  * parent (entity): the entity's new parent.
  """
  @spec change_parent(Entity.t(), Entity.t()) :: {:ok, Entity.t()} | {:error, binary()}
  def change_parent(%Entity{} = entity, %Entity{} = new_parent) do
    entity
    |> can_have_parent?(new_parent)
    |> maybe_change_parent(new_parent)
  end

  defp can_have_parent?(%Entity{} = entity, %Entity{} = new_parent) do
    id_or_key = Entity.get_id_or_key(entity)
    new_parent_id_or_key = Entity.get_id_or_key(new_parent)

    if id_or_key == new_parent_id_or_key do
      {:error, "An entity cannot be its own parent"}
    else
      is_ancestor? =
        new_parent_id_or_key
        |> Cache.get_ancestors_id_or_key()
        |> Enum.member?(id_or_key)

      if is_ancestor? do
        {:error, "#{id_or_key} is an ancestor of #{new_parent_id_or_key}, would create a loop"}
      else
        # Prevent cycles from below (descendant -> parent)
        if has_descendant?(entity, new_parent_id_or_key) do
          {:error, "#{new_parent_id_or_key} is a descendant of #{id_or_key}, would create a loop"}
        else
          {:ok, entity}
        end
      end
    end
  end

  defp has_descendant?(%Entity{} = entity, target_id_or_key) do
    id_or_key = Entity.get_id_or_key(entity)

    case Cache.get_children_id_or_key(id_or_key) do
      [] -> false
      children ->
        Enum.any?(children, fn child_id ->
          child_id == target_id_or_key or
            has_descendant?(get_entity(child_id), target_id_or_key)
        end)
    end
  end

  defp maybe_change_parent({:error, _} = error, _), do: error

  defp maybe_change_parent({:ok, %Entity{} = entity}, %Entity{} = parent) do

    if entity.id != :virtual do
      Repo.get(Record.Entity, entity.id)
      |> Record.Entity.changeset(%{parent_id: parent.id})
      |> Repo.update()
    end

    entity
    |> Cache.change_parent(parent)
    |> clear_parent_content()
    |> pull_parent_attributes()
    |> pull_parent_methods()
    |> Cache.cache_entity()
    |> then(&update_ancestry/1)
  end

  @doc """
  Set an entity attribute to any value.

  Arguments:

  * id_or_key (integer or string): the entity ID or key.
  * name (binary): the attribute's name to set (might exist).
  * value (any): the value to set.
  * opts (keyword list): the optional options to set.

  Options can be:

  * `:new`: only set the attribute if it doesn't exist.
  * `:cache`: just cache the attribute (never store it into the database).

  """
  @spec set_attribute(integer() | binary(), String.t(), any(), [atom()]) :: Entity.t() | :invalid_entity
  def set_attribute(id_or_key, name, value, opts \\ []) do
    case get_entity(id_or_key) do
      nil ->
        :invalid_entity

      entity ->
        set_entity_attribute(entity, name, value, opts)
        |> Cache.cache_entity()
        |> set_child_attribute(name, value)
    end
  end

  @doc """
  Set an entity method's code.

  Arguments:

  * id_or_key (integer or string) or key (binary): the entity ID or key.
  * name (binary): the method's name to set (might exist).
  * code (binary): the method code.
  * opts (keyword list): additional options.

  Options can be:

  * `:new`: only set the method if it doesn't exist.
  * `:cache`: just cache the method (never store it into the database).
  """
  @spec set_method(integer() | binary(), binary(), binary(), [atom()]) :: Entity.t() | :invalid_entity
  def set_method(id_or_key, name, code, opts \\ []) do
    case get_entity(id_or_key) do
      nil -> :invalid_entity
      entity ->
        set_entity_method(entity, name, code, opts)
        |> Cache.cache_entity()
        |> set_child_method(name, code)
    end
  end

  @doc """
  Deletes an entity.
  """
  @spec delete_entity(integer() | binary()) :: :ok | {:error, any()}
  def delete_entity(id_or_key) do
    case get_entity(id_or_key) do
      nil ->
        {:error, "invalid entity"}

      %Entity{id: :virtual} = entity ->
        delete_virtual_entity(entity)

      entity ->
        delete_stored_entity(entity)
    end
  end

  defp delete_virtual_entity(%Entity{key: nil}) do
    {:error, "cannot remove virtual entity with no key"}
  end

  defp delete_virtual_entity(entity) do
    Cache.uncache_entity(entity)

    :ok
  end

  defp delete_stored_entity(entity) do
    case Repo.get(Record.Entity, entity.id) do
      nil ->
        {:error, "this entity does not exist in storage"}

      record ->
        Repo.delete(record)

        Cache.uncache_entity(entity)

        :ok
    end
  end

  defp maybe_build_entity({:ok, %Entity{} = entity}) do
    entity =
      entity
      |> pull_parent_attributes()
      |> pull_parent_methods()
      |> Cache.cache_entity()

    {:ok, entity}
  end

  defp maybe_build_entity(other), do: other

  defp pull_parent_attributes(%Entity{parent_id: nil} = entity), do: entity

  defp pull_parent_attributes(%Entity{parent_id: parent_id_or_key} = entity) do
    parent = get_entity(parent_id_or_key)

    parent_attributes =
      parent.attributes
      |> Enum.map(fn {key, value} ->
        case value do
          {:parent, _} -> {key, value}
          _ -> {key, {:parent, parent_id_or_key}}
        end
      end)
      |> Map.new()

    attributes = Map.merge(parent_attributes, entity.attributes)

    %{entity | attributes: attributes}
  end

  defp pull_parent_methods(%Entity{parent_id: nil} = entity), do: entity

  defp pull_parent_methods(%Entity{parent_id: parent_id_or_key} = entity) do
    parent = get_entity(parent_id_or_key)

    parent_methods =
      parent.methods
      |> Enum.map(fn {key, value} ->
        case value do
          {:parent, _} -> {key, value}
          _ -> {key, {:parent, parent_id_or_key}}
        end
      end)
      |> Map.new()

    methods = Map.merge(parent_methods, entity.methods)

    %{entity | methods: methods}
  end

  defp set_entity_attribute(%Entity{id: :virtual} = entity, name, value, opts) do
    attributes =
      case opts[:new] do
        true -> Map.put_new(entity.attributes, name, value)
        _ -> Map.put(entity.attributes, name, value)
      end

    %{entity | attributes: attributes}
  end

  defp set_entity_attribute(%Entity{attributes: attributes} = entity, name, value, opts) do
    case Map.fetch(attributes, name) do
      :error ->
        create_entity_attribute_value(entity, name, value, opts)

      {:ok, former_value} ->
        case opts[:new] do
          true -> entity
          _ -> set_entity_attribute_value(entity, name, value, former_value, opts)
        end
    end
  end

  defp create_entity_attribute_value(%Entity{} = entity, name, value, opts) do
    attrs = %{entity_id: entity.id, name: name, value: :erlang.term_to_binary(value)}

    if opts[:cache] do
      {:ok, nil}
    else
      %Record.Attribute{}
      |> Record.Attribute.changeset(attrs)
      |> Repo.insert()
    end
    |> case do
      {:ok, attribute} ->
        if attribute do
          Cache.cache_stored_entity_attribute(entity, attribute)
        end

        %{entity | attributes: Map.put(entity.attributes, name, value)}

      error ->
        error
    end
  end

  defp set_entity_attribute_value(%Entity{} = entity, name, value, former, opts) do
    case Cache.get_cached_stored_entity_attribute(entity, name) do
      nil ->
        create_entity_attribute_value(entity, name, value, opts)

      attribute_id ->
        if opts[:cache] == nil do
          serialized = :erlang.term_to_binary(value)

          if :erlang.term_to_binary(former) != serialized do
            Repo.get(Record.Attribute, attribute_id)
            |> Record.Attribute.changeset(%{value: serialized})
            |> Repo.update()
          end
        end

        %{entity | attributes: Map.put(entity.attributes, name, value)}
    end
  end

  defp set_child_attribute(entity, name, value) do
    id_or_key = Entity.get_id_or_key(entity)

    for child <- get_children(entity) do
      child_id_or_key = Entity.get_id_or_key(child)

      case value do
        {:parent, other} -> set_attribute(child_id_or_key, name, {:parent, other}, new: true, cache: true)
        _ -> set_attribute(child_id_or_key, name, {:parent, id_or_key}, new: true, cache: true)
      end
    end

    entity
  end

  defp set_entity_method(%Entity{id: :virtual} = entity, name, code, opts) do
    method =
      case code do
        code when is_binary(code) -> %Pythelix.Method{name: name, code: code}
        other -> other
      end

    methods =
      case opts[:new] do
        true -> Map.put_new(entity.methods, name, method)
        _ -> Map.put(entity.methods, name, method)
      end

    %{entity | methods: methods}
  end

  defp set_entity_method(%Entity{methods: methods} = entity, name, code, opts) do
    case Map.fetch(methods, name) do
      :error ->
        create_entity_method_code(entity, name, code, opts)

      {:ok, _} ->
        case opts[:new] do
          true -> entity
          _ -> set_entity_method_code(entity, name, code, opts)
        end
    end
  end

  defp create_entity_method_code(%Entity{} = entity, name, code, opts) do
    attrs = %{entity_id: entity.id, name: name, value: code}

    if opts[:cache] do
      {:ok, nil}
    else
      %Record.Method{}
      |> Record.Method.changeset(attrs)
      |> Repo.insert()
    end
    |> case do
      {:ok, method} ->
        if method do
          Cache.cache_stored_entity_method(entity, method)
        end

        entity_method =
          case code do
            code when is_binary(code) -> %Pythelix.Method{name: name, code: code}
            other -> other
          end

        %{entity | methods: Map.put(entity.methods, name, entity_method)}

      error ->
        error
    end
  end

  defp set_entity_method_code(%Entity{} = entity, name, code, opts) do
    case Cache.get_cached_stored_entity_method(entity, name) do
      nil ->
        create_entity_method_code(entity, name, code, opts)

      method_id ->
        if opts[:cache] == nil do
          Repo.get(Record.Method, method_id)
          |> Record.Method.changeset(%{value: code})
          |> Repo.update()
        end

        method =
          case code do
            code when is_binary(code) -> %Pythelix.Method{name: name, code: code}
            other -> other
          end

        %{entity | methods: Map.put(entity.methods, name, method)}
    end
  end

  defp set_child_method(entity, name, code) do
    id_or_key = Entity.get_id_or_key(entity)

    for child <- get_children(entity) do
      child_id_or_key = Entity.get_id_or_key(child)

      case code do
        {:parent, other} -> set_method(child_id_or_key, name, {:parent, other}, cache: true)
        _ -> set_method(child_id_or_key, name, {:parent, id_or_key}, new: true, cache: true)
      end
    end

    entity
  end

  defp update_ancestry(entity) do
    for child <- get_children(entity) do
      child
      |> Cache.update_ancestors()
      |> clear_parent_content()
      |> pull_parent_attributes()
      |> pull_parent_methods()
      |> Cache.cache_entity()
      |> update_ancestry()
    end

    entity
  end

  defp clear_parent_content(%Entity{} = entity) do
    entity
    |> clear_parent_attributes()
    |> clear_parent_methods()
  end

  defp clear_parent_attributes(%Entity{} = entity) do
    attributes =
      entity.attributes
      |> Enum.reject(fn {_, value} -> match?({:parent, _}, value) end)
      |> Map.new()

    %{entity | attributes: attributes}
  end

  defp clear_parent_methods(%Entity{} = entity) do
    methods =
      entity.methods
      |> Enum.reject(fn {_, value} -> match?({:parent, _}, value) end)
      |> Map.new()

    %{entity | methods: methods}
  end
end
