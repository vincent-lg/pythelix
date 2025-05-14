defmodule Pythelix.Record.Cache do
  @moduledoc """
  Helper functions to manipulate entities in the cache.
  """

  alias Pythelix.Entity
  alias Pythelix.Record

  def warmup() do
    Cachex.get(:px_cache, 0)
  end

  @doc """
  Clear the cache.
  This will force Pthelix to reconstruct it (fresh) from the database.
  If you'd like to commit the changes to the database, use
  `commit_and_clear` instead.
  """
  @spec clear() :: :ok
  def clear() do
    Cachex.clear(:px_cache)
    Cachex.clear(:px_diff)
    Pythelix.Record.Diff.init()
    :ok
  end

  @doc """
  Commit the cached changes to the database and then clear the cache.
  This is most useful for testing in particular.
  """
  @spec commit_and_clear() :: :ok
  def commit_and_clear() do
    Pythelix.Record.Diff.apply()
    clear()
  end

  def cache_parent_children(entities) do
    cache_parent_entities(entities)
    cache_child_entities(entities)
  end

  defp cache_parent_entities(entities) do
    entities
    |> Enum.each(fn %{id: id, parent_id: parent_id} ->
      if parent_id do
        Cachex.put(:px_cache, {:parent, id}, parent_id)
      end
    end)
  end

  defp cache_child_entities(entities) do
    entities
    |> Enum.each(fn %{id: id, parent_id: parent_id} ->
      if parent_id do
        Cachex.get_and_update(:px_cache, {:children, parent_id}, fn
          nil -> {:commit, [id]}
          children -> {:commit, [id | children]}
        end)
      end
    end)
  end

  def cache_location_contents(entities) do
    cache_location_entities(entities)
    cache_contents_entities(entities)
  end

  defp cache_location_entities(entities) do
    entities
    |> Enum.each(fn %{id: id, location_id: location_id} ->
      if location_id do
        Cachex.put(:px_cache, {:location, id}, location_id)
      end
    end)
  end

  defp cache_contents_entities(entities) do
    entities
    |> Enum.each(fn %{id: id, location_id: location_id} ->
      if location_id do
        Cachex.get_and_update(:px_cache, {:contents, location_id}, fn
          nil -> {:commit, [id]}
          contents -> {:commit, [id | contents]}
        end)
      end
    end)
  end

  @doc """
  Returns the entity if cached, or nil.

  Args:

  * id_or_key (integer or string): the ID or key of this entity.

  """
  @spec get_cached_entity(integer() | binary()) :: Entity.t() | nil
  def get_cached_entity(id_or_key) when is_integer(id_or_key) or is_binary(id_or_key) do
    case Cachex.get(:px_cache, id_or_key) do
      {:ok, nil} -> nil
      {:ok, entity} -> entity
    end
  end

  @doc """
  Cache an entity.

  Args:

  * entity (Entity): the entity to cache or recache.

  """
  @spec cache_entity(Entity.t()) :: Entity.t()
  def cache_entity(%Entity{} = entity) do
    entity
    |> maybe_cache_entity_id()
    |> maybe_cache_entity_key()
    |> maybe_cache_parent_children()
    |> maybe_cache_entity_ancestors()
  end

  @doc """
  Change the parent in cache.

  Args:

  * entity (Entity): the entity to change parent.
  * parent (Entity): the new parent.
  """
  @spec change_parent(Entity.t(), Entity.t() | nil) :: Entity.t()
  def change_parent(entity, parent) do
    id_or_key = Entity.get_id_or_key(entity)
    parent_id_or_key = (parent && Entity.get_id_or_key(parent)) || nil

    if new_parent_id_or_key = entity.parent_id do
      remove_child_from(new_parent_id_or_key, id_or_key)
    end

    if parent do
      add_child_to(Entity.get_id_or_key(parent), id_or_key)
    end

    %{entity | parent_id: parent_id_or_key}
    |> update_ancestors()
  end

  @doc """
  Change the location in cache.

  Args:

  * entity (Entity): the entity to change location.
  * location (Entity): the new location.
  """
  @spec change_location(Entity.t(), Entity.t() | nil) :: Entity.t()
  def change_location(entity, location) do
    id_or_key = Entity.get_id_or_key(entity)
    location_id_or_key = (location && Entity.get_id_or_key(location)) || nil

    if old_location_id_or_key = entity.location_id do
      remove_contained_from(old_location_id_or_key, id_or_key)
    end

    if location do
      add_contained_to(location_id_or_key, id_or_key)
    end

    %{entity | location_id: location_id_or_key}
  end

  def retrieve_entity_location(%Entity{location_id: nil} = entity), do: entity

  def retrieve_entity_location(%Entity{location_id: location_id_or_key} = entity) do
    add_contained_to(location_id_or_key, Entity.get_id_or_key(entity))

    entity
  end

  @doc """
  Updates the ancestors of the specified entity.

  This function is useful if the entity has changed parents (or a parent
  has changed in its ancestry) but it doesn't know about it yet.
  This recalculates ancestors based on the parent entity records which,
  at this point, has to reflect the new tree of ancestors.

  Args:

  * entity (Entity): the entity for which the ancestros should be recalculated.

  """
  @spec update_ancestors(Entity.t()) :: Entity.t()
  def update_ancestors(%{parent_id: parent_id_or_key} = entity) do
    id_or_key = Entity.get_id_or_key(entity)
    Cachex.put(:px_cache, {:parent, id_or_key}, parent_id_or_key)

    entity
  end

  @doc """
  Remove an entity from the cache.

  Args:

  * entity (Entity): the entity to delete from cache.

  """
  @spec uncache_entity(Entity.t()) :: :ok
  def uncache_entity(entity) do
    id_or_key = Entity.get_id_or_key(entity)

    if entity.id != :virtual do
      Cachex.del(:px_cache, entity.id)
    end

    if entity.key do
      Cachex.del(:px_cache, entity.key)
    end

    if parent = entity.parent_id do
      remove_child_from(parent, id_or_key)
    end

    if location = entity.location_id do
      remove_contained_from(location, id_or_key)
    end
  end

  @doc """
  Get the children ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_children_id_or_key(integer() | binary()) :: [integer() | binary()]
  def get_children_id_or_key(id_or_key) do
    case Cachex.get(:px_cache, {:children, id_or_key}) do
      {:ok, nil} -> []
      {:ok, children} -> children
    end
  end

  @doc """
  Get the ancestors ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_ancestors_id_or_key(integer() | binary()) :: [integer() | binary()]
  def get_ancestors_id_or_key(id_or_key) do
    id_or_key
    |> get_recursive_ancestors()
  end

  @doc """
  Get the locations ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_locations_id_or_key(integer() | binary()) :: [integer() | binary()]
  def get_locations_id_or_key(id_or_key) do
    id_or_key
    |> get_recursive_locations()
  end

  @doc """
  Get the location ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_location_id_or_key(integer() | binary()) :: integer() | binary() | nil
  def get_location_id_or_key(id_or_key) do
    case Cachex.get(:px_cache, {:location, id_or_key}) do
      {:ok, nil} -> nil
      {:ok, location} -> location
    end
  end

  @doc """
  Get the contained ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_contained_id_or_key(integer() | binary()) :: [integer() | binary()]
  def get_contained_id_or_key(id_or_key) do
    case Cachex.get(:px_cache, {:contents, id_or_key}) do
      {:ok, nil} -> []
      {:ok, contained} -> contained
    end
  end

  @doc """
  Get the contents' ID or key of a given entity ID or key.

  Args:

  * id_or_key (integer or string): the entity's ID or key.
  """
  @spec get_contents_id_or_key(integer() | binary()) :: [integer() | binary()]
  def get_contents_id_or_key(id_or_key) do
    id_or_key
    |> get_recursive_contents()
  end

  defp get_recursive_ancestors(id_or_key) do
    case Cachex.get(:px_cache, {:parent, id_or_key}) do
      {:ok, nil} ->
        []

      {:ok, parent_id} ->
        [parent_id | get_recursive_ancestors(parent_id)]
    end
  end

  defp get_recursive_locations(id_or_key) do
    case Cachex.get(:px_cache, {:location, id_or_key}) do
      {:ok, nil} ->
        []

      {:ok, location_id} ->
        [location_id | get_recursive_locations(location_id)]
    end
  end

  defp get_recursive_contents(id_or_key) do
    case Cachex.get(:px_cache, {:contents, id_or_key}) do
      {:ok, nil} ->
        []

      {:ok, contents} ->
        contents
        |> Enum.flat_map(&get_recursive_contents/1)
        |> then(& Enum.concat(contents, &1))
    end
  end

  @doc """
  Cache entity attributes coming from the database.

  Args:

  * entity (Record.Entity): a stored entity.

  """
  @spec cache_stored_entity_attributes(map()) :: map()
  def cache_stored_entity_attributes(%Record.Entity{attributes: attributes} = entity)
       when is_list(attributes) do
    for attribute <- attributes do
      cache_stored_entity_attribute(entity, attribute)
    end

    entity
  end

  def cache_stored_entity_attributes(%Record.Entity{} = entity), do: entity

  def cache_stored_entity_attribute(entity, attribute) do
    Cachex.put(:px_cache, {:attribute, entity.id, attribute.name}, attribute.id)
  end

  def get_cached_stored_entity_attribute(entity, name) do
    case Cachex.get(:px_cache, {:attribute, entity.id, name}) do
      {:ok, nil} ->
        nil

      {:ok, attribute_id} ->
        attribute_id
    end
  end

  defp maybe_cache_entity_id(%Entity{id: :virtual} = entity), do: entity

  defp maybe_cache_entity_id(%Entity{} = entity) do
    Cachex.put(:px_cache, entity.id, entity)

    entity
  end

  defp maybe_cache_entity_key(%Entity{key: nil} = entity), do: entity

  defp maybe_cache_entity_key(%Entity{} = entity) do
    Cachex.put(:px_cache, entity.key, entity)

    entity
  end

  defp maybe_cache_parent_children(%Entity{parent_id: nil} = entity), do: entity

  defp maybe_cache_parent_children(%Entity{parent_id: parent} = entity) do
    id_or_key = Entity.get_id_or_key(entity)

    children =
      case Cachex.get(:px_cache, {:children, parent}) do
        {:ok, nil} ->
          [id_or_key]

        {:ok, former_children} ->
          [id_or_key | former_children]
          |> Enum.uniq()
      end

    Cachex.put(:px_cache, {:children, parent}, children)

    entity
  end

  defp maybe_cache_entity_ancestors(%Entity{parent_id: nil} = entity), do: entity

  defp maybe_cache_entity_ancestors(%Entity{} = entity) do
    entity
    |> update_ancestors()
  end

  defp remove_child_from(parent_id_or_key, entity_id_or_key) do
    children =
      parent_id_or_key
      |> get_children_id_or_key()
      |> Enum.reject(&(&1 == entity_id_or_key))

    Cachex.put(:px_cache, {:children, parent_id_or_key}, children)
  end

  defp add_child_to(parent_id_or_key, entity_id_or_key) do
    children =
      case Cachex.get(:px_cache, {:children, parent_id_or_key}) do
        {:ok, nil} ->
          [entity_id_or_key]

        {:ok, former_children} ->
          [entity_id_or_key | former_children]
          |> Enum.uniq()
      end

    Cachex.put(:px_cache, {:children, parent_id_or_key}, children)
  end

  defp remove_contained_from(location_id_or_key, entity_id_or_key) do
    # Remove entity from its location contained.
    Cachex.get_and_update(:px_cache, {:contents, location_id_or_key}, fn
      nil -> {:ignore, []}
      contents -> {:commit, Enum.reject(contents, &(&1 == entity_id_or_key))}
    end)

    # Remove location from the entity.
    Cachex.del(:px_cache, {:location, entity_id_or_key})
  end

  defp add_contained_to(location_id_or_key, entity_id_or_key) do
    # Add entity from its location contained.
    Cachex.get_and_update(:px_cache, {:contents, location_id_or_key}, fn
      nil -> {:commit, [entity_id_or_key]}
      contained -> {:commit, contained ++ [entity_id_or_key]}
    end)

    # Add location from the entity.
    if location_id_or_key do
      Cachex.put(:px_cache, {:location, entity_id_or_key}, location_id_or_key)
    else
      Cachex.del(:px_cache, {:location, entity_id_or_key})
    end
  end
end
