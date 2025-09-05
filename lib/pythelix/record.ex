defmodule Pythelix.Record do
  @moduledoc """
  The record context, to manipulate entities in the database.
  """

  import Ecto.Query, warn: false
  alias Pythelix.Repo
  alias Pythelix.{Entity, Method}
  alias Pythelix.Network.TCP.Client
  alias Pythelix.Record
  alias Pythelix.Record.Cache
  alias Pythelix.Record.Diff
  alias Pythelix.Scripting.Runner

  def warmup() do
    warmup_database()
    warmup_cache()
  end

  @doc """
  Cache parent and location for each stored entity.
  """
  @spec cache_relationships() :: :ok
  def cache_relationships() do
    query =
      from e in Record.Entity,
        select: %{id: e.gen_id, parent_id: e.parent_id, location_id: e.location_id}

    Repo.all(query)
    |> tap(&Cache.cache_parent_children/1)
    |> tap(&Cache.cache_location_contents/1)
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
    |> Cache.cache_stored_entity_methods(methods)
    |> Entity.new(key)
    |> Cache.retrieve_entity_location()
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

    entity
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
  Returns whether this entity has this parent in its ancestors.

  Args:

  * entity (Entity): the entity to test.
  * parent (Entity, String or integer): the entity parent.
  """
  @spec has_parent?(Entity.t(), Entity.t() | String.t() | integer()) :: boolean()
  def has_parent?(nil, _menu), do: false
  def has_parent?(_entity, nil), do: false
  def has_parent?(%Entity{} = entity, %Entity{} = parent) do
    has_parent?(entity, Entity.get_id_or_key(parent))
  end

  def has_parent?(%Entity{} = entity, parent) when is_integer(parent) or is_binary(parent) do
    entity
    |> Entity.get_id_or_key()
    |> Cache.get_ancestors_id_or_key()
    |> Enum.member?(parent)
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
    if key = opts[:key] do
      if get_entity(key) do
        {:error, "the #{key} key already exists"}
      else
        :ok
      end
    else
      :ok
    end
    |> then(fn
      :ok ->
        case opts[:virtual] do
          nil -> create_stored_entity(opts)
          _ -> create_virtual_entity(opts)
        end

      other -> other
    end)
    |> maybe_build_entity()
  end

  defp create_virtual_entity(opts) do
    parent_id = (opts[:parent] && opts[:parent].key) || nil
    location_id = (opts[:location] && opts[:location].key) || nil

    if key = opts[:key] do
      entity =
        %Entity{
          id: :virtual,
          key: key,
          parent_id: parent_id,
          location_id: location_id
        }

      {:ok, entity}
    else
      {:error, "a key is mandatory for a virtual entity"}
    end
  end

  defp create_stored_entity(opts) do
    key = opts[:key]
    parent_id = (opts[:parent] && opts[:parent].id) || nil
    location_id = (opts[:location] && opts[:location].id) || nil

    gen_id = Diff.get_entity_id()
    Diff.add({:add, gen_id, key, parent_id, location_id})

    entity = %Entity{
      id: gen_id,
      key: key,
      parent_id: parent_id,
      location_id: location_id
    }

    {:ok, entity}
  end

  @doc """
  Change the parent of the specified entity.

  Check that this would not create cyclical relations

  Args:

  * entity (entity): the entity whose parent is to change.
  * parent (entity): the entity's new parent.
  """
  @spec change_parent(Entity.t(), Entity.t() | nil) :: Entity.t() | {:error, binary()}
  def change_parent(%Entity{} = entity, new_parent) do
    entity
    |> can_have_parent?(new_parent)
    |> maybe_change_parent(new_parent)
  end

  defp can_have_parent?(%Entity{} = entity, nil), do: {:ok, entity}

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
      parent_id = (parent && parent.id) || nil
      Diff.add({:update, entity.id, :parent_id, parent_id})
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
  @spec change_location(Entity.t(), Entity.t() | nil) :: Entity.t() | {:error, String.tOP}
  def change_location(%Entity{} = entity, new_location) do
    entity
    |> can_move_to_location?(new_location)
    |> maybe_change_location(new_location)
  end

  defp can_move_to_location?(%Entity{} = entity, nil), do: {:ok, entity}

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
      location_id = (new_location && new_location.id) || nil
      Diff.add({:update, entity.id, :location_id, location_id})
    end

    entity
    |> tap(& handle_changed_location(&1, new_location))
    |> Cache.change_location(new_location)
    |> Cache.cache_entity()
    |> tap(& handle_new_location(&1, new_location))
  end

  defp handle_changed_location(%{location_id: old_id} = entity, location) do
    old_location = (old_id && get_entity(old_id)) || nil

    if location != old_location do
      if has_parent?(entity, "generic/client") && has_parent?(old_location, "generic/menu") do
        owner = get_attribute(entity, "owner", nil)
        owner = owner || entity
        try do
          Runner.run_method({old_location, "leave"}, [owner], nil, sync: true)
        rescue
          _ -> nil
        end
      end
    end
  end

  defp handle_new_location(entity, location) do
    if has_parent?(entity, "generic/client") && has_parent?(location, "generic/menu") do
      try do
        case Method.call_entity(location, "get_text", [entity]) do
          :nomethod ->
            nil

          text ->
            Client.send(entity, text)
        end
      rescue
        _ -> nil
      end

      owner = get_attribute(entity, "owner", nil)
      owner = owner || entity
      #try do
        Runner.run_method({location, "enter"}, [owner], nil, sync: true)
      #rescue
      #  _ -> nil
      #end
    end
  end

  @doc """
  Get the attributes of an entity in a map.

  Args:

  - `entity`: the entity from which to return attributes.
  - `opts`: optionally a keyword list with options.

  Supported options:

  - `raw_parents`: if `true`, leave the parent attribute as their raw representation.
  """
  @spec get_attributes(Entity.t(), Keyword.t()) :: map()
  def get_attributes(%Entity{} = entity, opts \\ []) do
    Cache.get_cached_entity_attributes(entity, opts)
  end

  @doc """
  Get the attribute of an entity, or nil.

  Args:

  - `entity`: the entity from which to return attribute.
  * `name`: the name of the attribute to get.
  - `opts`: optionally a keyword list with options.

  Supported options:

  - `raw_parents`: if `true`, leave the parent attribute as its raw representation.
  """
  @spec get_attribute(Entity.t(), String.t(), any(), Keyword.t()) :: any()
  def get_attribute(%Entity{} = entity, name, default \\ nil, opts \\ []) do
    Cache.get_cached_entity_attribute(entity, name, default, opts)
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
        |> set_child_attribute(name, value)
    end
  end

  @doc """
  Get the methods of an entity in a map.

  Args:

  - `entity`: the entity from which to return methods.
  - `opts`: optionally a keyword list with options.

  Supported options:

  - `raw_parents`: if `true`, leave the parent method as their raw representation.
  """
  @spec get_methods(Entity.t(), Keyword.t()) :: map()
  def get_methods(%Entity{} = entity, opts \\ []) do
    Cache.get_cached_entity_methods(entity, opts)
  end

  @doc """
  Get the method of an entity, or nil.

  Args:

  - `entity`: the entity from which to return method.
  - `name`: the name of the method to get.
  - `opts`: optionally a keyword list with options.

  Supported options:

  - `raw_parents`: if `true`, leave the parent method as its raw representation.
  """
  @spec get_method(Entity.t(), String.t(), Keyword.t()) :: any()
  def get_method(%Entity{} = entity, name, opts \\ []) do
    Cache.get_cached_entity_method(entity, name, opts)
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
  @spec set_method(integer() | binary(), list(), binary(), binary(), [atom()]) :: Entity.t() | :invalid_entity
  def set_method(id_or_key, name, args, code, opts \\ []) do
    case get_entity(id_or_key) do
      nil -> :invalid_entity
      entity ->
        set_entity_method(entity, name, args, code, opts)
        |> set_child_method(name, args)
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
    Cache.uncache_entity(entity)
    Diff.add({:delete, entity.id})

    :ok
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
    id_or_key = Entity.get_id_or_key(entity)
    parent = get_entity(parent_id_or_key)

    parent_attributes =
      Cache.get_cached_entity_attributes(parent, raw_parents: true)
      |> Enum.map(fn {key, value} ->
        case value do
          {:parent, _} -> {key, value}
          _ -> {key, {:parent, parent_id_or_key}}
        end
      end)
      |> Map.new()

    Map.merge(parent_attributes, get_attributes(entity, raw_parents: true))
    |> Enum.each(fn {name, value} ->
      Cache.cache_entity_attribute(id_or_key, name, value)
    end)

    entity
  end

  defp pull_parent_methods(%Entity{parent_id: nil} = entity), do: entity

  defp pull_parent_methods(%Entity{parent_id: parent_id_or_key} = entity) do
    id_or_key = Entity.get_id_or_key(entity)
    parent = get_entity(parent_id_or_key)

    parent_methods =
      Cache.get_cached_entity_methods(parent, raw_parents: true)
      |> Enum.map(fn {key, value} ->
        case value do
          {:parent, _} -> {key, value}
          _ -> {key, {:parent, parent_id_or_key}}
        end
      end)
      |> Map.new()

    Map.merge(parent_methods, get_methods(entity, raw_parents: true))
    |> Enum.each(fn {name, value} ->
      Cache.cache_entity_method(id_or_key, name, value)
    end)

    entity
  end

  defp set_entity_attribute(%Entity{id: :virtual} = entity, name, value, _opts) do
    id_or_key = Entity.get_id_or_key(entity)

    Cache.cache_entity_attribute(id_or_key, name, value)

    entity
  end

  defp set_entity_attribute(%Entity{} = entity, name, value, opts) do
    attributes = Cache.get_cached_entity_attributes(entity)

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
    if opts[:cache] do
      {:ok, nil, value}
    else
      serialized = :erlang.term_to_binary(value)

      gen_id = Diff.get_attribute_id()
      Diff.add({:addattr, entity.id, gen_id, name, serialized})
      attribute = %{
        gen_id: gen_id,
        name: name,
        value: serialized
      }

      {:ok, attribute, value}
    end
    |> case do
      {:ok, attribute, value} ->
        if attribute do
          Cache.cache_stored_entity_attribute(entity.id, attribute, value)
        else
          Cache.cache_entity_attribute(entity.id, name, value)
        end

        entity

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
            Diff.add({:setattr, attribute_id, name, serialized})
          end
        end
        Cache.cache_entity_attribute(Entity.get_id_or_key(entity), name, value)

        entity
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

  defp set_entity_method(%Entity{id: :virtual} = entity, name, args, code, _opts) do
    method =
      if code == nil do
        args
      else
        Method.new(args, code)
      end

    Cache.cache_entity_method(entity.key, name, method)

    entity
  end

  defp set_entity_method(%Entity{} = entity, name, args, code, opts) do
    methods = Cache.get_cached_entity_methods(entity, raw_parents: true)

    case Map.fetch(methods, name) do
      :error ->
        set_entity_method_code(entity, name, args, code, opts)

      {:ok, _} ->
        case opts[:new] do
          true -> entity
          _ -> set_entity_method_code(entity, name, args, code, opts)
        end
    end
  end

  defp set_entity_method_code(%Entity{} = entity, name, args, code, _opts) do
    id_or_key = Entity.get_id_or_key(entity)
    method =
      if code == nil do
        args
      else
        Method.new(args, code)
      end

    Cache.cache_entity_method(id_or_key, name, method)

    to_store =
      Cache.get_cached_entity_methods(entity, raw_parents: true)
      |> Enum.map(fn
        {_, {:parent, _}} -> nil
        {name, method} -> {name, {method.args, method.code, method.bytecode}}
      end)
      |> Enum.reject(& &1 == nil)
      |> Map.new()

    Diff.add({:update, entity.id, :methods, :erlang.term_to_binary(to_store)})

    entity
  end

  defp set_child_method(entity, name, args) do
    id_or_key = Entity.get_id_or_key(entity)

    for child <- get_children(entity) do
      child_id_or_key = Entity.get_id_or_key(child)

      case args do
        {:parent, other} -> set_method(child_id_or_key, name, {:parent, other}, nil, new: true, cache: true)
        _ -> set_method(child_id_or_key, name, {:parent, id_or_key}, nil, new: true, cache: true)
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
    Cache.get_cached_entity_attributes(entity, raw_parents: true)
    |> Enum.reject(fn {_, value} -> !match?({:parent, _}, value) end)
    |> Enum.map(fn {name, _} -> Cache.uncache_entity_attribute(entity, name) end)

    entity
  end

  defp clear_parent_methods(%Entity{} = entity) do
    Cache.get_cached_entity_methods(entity, raw_parents: true)
    |> Enum.reject(fn {_, value} -> !match?({:parent, _}, value) end)
    |> Enum.map(fn {name, _} -> Cache.uncache_entity_method(entity, name) end)

    entity
  end

  defp warmup_database() do
    get_entity(0)
  end

  def warmup_cache() do
    Cache.warmup()
  end
end
