defmodule Pythelix.Record.Cache do
  @moduledoc """
  Helper functions to manipulate entities in the cache.
  """

  alias Pythelix.Entity
  alias Pythelix.Record

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
  Updates the ancestors of the specified entity.

  This function is useful if the entity has changed parents (or a parent
  has changed in its ancestry) but it doesn't know about it yet.
  This recalculates ancestors based on the parent entity records which,
  at this point, has to reflect the new tree of ancestors.

  Args:

  * entity (Entity): the entity for which the ancestros should be recalculated.

  """
  @spec update_ancestors(Entity.t()) :: Entity.t()
  def update_ancestors(entity) do
    id_or_key = Entity.get_id_or_key(entity)
    parent_id_or_key = entity.parent_id

    if parent_id_or_key do
      new_ancestors =
        case Cachex.get(:px_cache, {:ancestors, parent_id_or_key}) do
          {:ok, nil} ->
            [parent_id_or_key]

          {:ok, ancestors} ->
            [parent_id_or_key | ancestors]
            |> Enum.uniq()
        end

      Cachex.put(:px_cache, {:ancestors, id_or_key}, new_ancestors)
    else
      Cachex.del(:px_cache, {:ancestors, id_or_key})
    end

    entity
  end

  @doc """
  Remove an entity from the cache.

  Args:

  * entity (Entity): the entity to delete from cache.

  """
  @spec uncache_entity(Entity.t()) :: :ok
  def uncache_entity(entity) do
    if entity.id != :virtual do
      Cachex.del(:px_cache, entity.id)
    end

    if entity.key do
      Cachex.del(:px_cache, entity.key)
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
    case Cachex.get(:px_cache, {:ancestors, id_or_key}) do
      {:ok, nil} -> []
      {:ok, ancestors} -> ancestors
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

  @doc """
  Cache entity methods coming from the database.

  Args:

  * entity (Record.Entity): a stored entity.

  """
  @spec cache_stored_entity_methods(map()) :: map()
  def cache_stored_entity_methods(%Record.Entity{methods: methods} = entity)
       when is_list(methods) do
    for method <- methods do
      cache_stored_entity_method(entity, method)
    end

    entity
  end

  def cache_stored_entity_methods(%Record.Entity{} = entity), do: entity

  def cache_stored_entity_method(entity, method) do
    Cachex.put(:px_cache, {:method, entity.id, method.name}, method.id)
  end

  def get_cached_stored_entity_method(entity, name) do
    case Cachex.get(:px_cache, {:method, entity.id, name}) do
      {:ok, nil} ->
        nil

      {:ok, method_id} ->
        method_id
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
end
