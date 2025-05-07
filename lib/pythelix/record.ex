defmodule Pythelix.Record do
  @moduledoc """
  The record context, to manipulate entities in the database.
  """

  import Ecto.Query, warn: false
  alias Pythelix.Repo
  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Record.Cache

  def warmup() do
    warmup_database()
    warmup_cache()
  end

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
        Repo.get_by(Record.Entity, key: key)
        |> maybe_load_stored_entity()

      entity ->
        entity
    end
  end

  def get_entity(id) when is_integer(id) do
    case Cache.get_cached_entity(id) do
      nil ->
        Repo.get(Record.Entity, id)
        |> maybe_load_stored_entity()

      entity ->
        entity
    end
  end

  defp maybe_load_stored_entity(nil), do: nil

  defp maybe_load_stored_entity(entity) do
    key = entity.key
    methods = Record.Entity.get_methods(entity)

    entity
    |> Repo.preload(:attributes)
    |> Cache.cache_stored_entity_attributes()
    |> Entity.new(key, methods)
    |> tap(&get_location_entity(&1, recursive: true))
    |> pull_parent_attributes()
    |> pull_parent_methods()
    |> Cache.cache_entity()
  end

  @doc """
  Return the parent's entity.

  If opts["recursive], tap the DB/Cache.

  Args:

  * entity (Entity): the entity.
  """
  def get_location_entity(entity, opts \\ [])

  def get_location_entity(%Entity{location_id: nil}, _opts), do: nil

  def get_location_entity(%Entity{location_id: location_id_or_key}, opts) do
    entity = get_entity(location_id_or_key)

    if opts[:recursive] do
      get_location_entity(entity, opts)
    end
  end

  @doc """
  Gets the children id or keys from an entity id or key.

  Returns a list of strings (keys) or inegers (IDs).

  Args:

    * parent_id_or_key (string): the parent ID or key.

  """
  def get_children_id_or_key(parent_id_or_key) do
    parent_id_or_key
    |> Cache.get_children_id_or_key()
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
    |> get_children_id_or_key()
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
  Gets the location from an entity.

  Returns the entity in which the specified entity is located, or nil.

  Args:

    * entity (entity): the child entity.

  """
  @spec get_location(Entity.t()) :: Entity.t() | nil
  def get_location(%Entity{} = entity) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_location_id_or_key()
    |> then(&(&1 && get_entity(&1)))
  end

  @doc """
  Gets the locations from an entity.

  Returns a list of entities (location tree).

  Args:

    * entity (entity): the child entity.

  """
  @spec get_locations(Entity.t()) :: [Entity.t()]
  def get_locations(%Entity{} = entity) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_locations_id_or_key()
    |> Enum.map(&get_entity/1)
  end

  @doc """
  Gets the contained entities from an entity.

  Returns a list of contained (entities inside the specified entity,
  first-level only).

  Args:

    * entity (entity): the child entity.

  """
  @spec get_contained(Entity.t()) :: [Entity.t()]
  def get_contained(%Entity{} = entity) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_contained_id_or_key()
    |> Enum.map(&get_entity/1)
  end

  @doc """
  Gets the contents from an entity.

  Returns a list of entities (all contained within the specified entity
  at any level).

  Args:

    * entity (entity): the child entity.

  """
  @spec get_contents(Entity.t()) :: [Entity.t()]
  def get_contents(%Entity{} = entity) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_contents_id_or_key()
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
    key = opts[:key]
    parent_id = (opts[:parent] && opts[:parent].id) || nil
    location_id = (opts[:location] && opts[:location].id) || nil

    Repo.transaction(fn ->
      # Check if the key is present and unique
      if key && Repo.get_by(Record.Entity, key: key) do
        Repo.rollback("Key already exists")
      end

      # Create the entity
      attrs = %{location_id: location_id, parent_id: parent_id, key: key}

      %Record.Entity{}
      |> Record.Entity.changeset(attrs)
      |> Record.Entity.put_methods(%{})
      |> Repo.insert()
    end)
    |> case do
      {:ok, {:ok, entity}} ->
        entity = Entity.new(entity, key)

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
  Change the location of an entity.

  If the change isn't possible, returns `{:cycle, ...}`.

  Args:

  * entity (Entity): the entity to move.
  * location (Entity): the new location.
  """
  @spec change_location(Entity.t(), Entity.t()) :: {:error, String.tOP}
  def change_location(%Entity{} = entity, %Entity{} = new_location) do
    entity
    |> can_move_to_location?(new_location)
    |> maybe_change_location(new_location)
  end

  defp can_move_to_location?(%Entity{} = entity, %Entity{} = new_location) do
    id_or_key = Entity.get_id_or_key(entity)
    new_location_id = Entity.get_id_or_key(new_location)

    if id_or_key == new_location_id do
      {:error, "An entity cannot be located in itself"}
    else
      # Prevent upward cycle
      locations = Cache.get_locations_id_or_key(new_location_id)

      if Enum.member?(locations, id_or_key) do
        {:error, "This would create a cyclical location dependency"}
      else
        {:ok, entity}
      end
    end
  end

  defp maybe_change_location({:error, _} = error, _), do: error

  defp maybe_change_location({:ok, entity}, new_location) do
    if entity.id != :virtual do
      Repo.get(Record.Entity, entity.id)
      |> Record.Entity.changeset(%{location_id: new_location.id})
      |> Repo.update()
    end

    entity
    |> Cache.change_location(new_location)
    |> Cache.cache_entity()
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
      |> Cache.retrieve_entity_location()
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
        set_entity_method_code(entity, name, code, opts)

      {:ok, _} ->
        case opts[:new] do
          true -> entity
          _ -> set_entity_method_code(entity, name, code, opts)
        end
    end
  end

  defp set_entity_method_code(%Entity{} = entity, name, code, _opts) do
    method =
      case code do
        code when is_binary(code) -> %Pythelix.Method{name: name, code: code}
        other -> other
      end

    entity = %{entity | methods: Map.put(entity.methods, name, method)}

    to_store =
      entity.methods
      |> Enum.filter(fn
        {_, {:parent, _}} -> false
        {name, method} -> {name, method.code}
      end)
      |> Map.new()

    Repo.get(Record.Entity, entity.id)
    |> Record.Entity.changeset(%{})
    |> Record.Entity.put_methods(to_store)
    |> Repo.update()

    entity
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

  defp warmup_database() do
    get_entity(0)
  end

  def warmup_cache() do
    Cache.warmup()
  end
end
