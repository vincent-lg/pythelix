defmodule Pythelix.Record do
  @moduledoc """
  The record context, to manipulate entities in the database.
  """

  import Ecto.Query, warn: false
  alias Pythelix.Repo
  alias Pythelix.Entity
  alias Pythelix.Record

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
    case Cachex.get(:px_cache, key) do
      {:ok, nil} ->
        case Repo.get_by(Record.Key, key: key) do
          nil -> nil
          %Record.Key{entity_id: entity_id} -> get_entity(entity_id)
        end

      {:ok, entity} ->
        entity
    end
  end

  def get_entity(id) when is_integer(id) do
    case Cachex.get(:px_cache, id) do
      {:ok, nil} ->
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
              |> cache_entity_attributes()
              |> cache_entity_methods()
              |> Entity.new(key)
              |> cache_entity()

            entity
        end

      {:ok, entity} ->
        entity
    end
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

    entity =
      entity
      |> cache_entity()

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
        entity =
          Entity.new(entity, opts[:key])
          |> cache_entity()

        {:ok, entity}

      other ->
        other
    end
  end

  @doc """
  Set an entity attribute to any value.

  Arguments:

  * id (integer): the entity ID.
  * name (binary): the attribute's name to set (might exist).
  * value (any): the value to set.

  """
  @spec set_attribute(integer() | binary(), String.t(), any()) :: :ok | :invalid_entity
  def set_attribute(id_or_key, name, value) do
    case get_entity(id_or_key) do
      nil -> :invalid_entity
      entity -> set_entity_attribute(entity, name, value)
    end
  end

  @doc """
  Set an entity method's code.

  Arguments:

  * id (integer) or key (binary): the entity ID.
  * name (binary): the method's name to set (might exist).
  * code (binary): the method code.

  """
  @spec set_method(integer() | binary(), String.t(), String.t()) :: :ok | :invalid_entity
  def set_method(id_or_key, name, code) do
    case get_entity(id_or_key) do
      nil -> :invalid_entity
      entity -> set_entity_method(entity, name, code)
    end
  end

  @doc """
  Deletes an entity.

  ## Examples

      iex> delete_entity(5)
      {:ok, %Entity{}}

      iex> delete_entity(99)
      {:error, %Ecto.Changeset{}}

  """
  def delete_entity(entity_id_or_key) do
    entity = get_entity(entity_id_or_key)

    case entity do
      nil ->
        {:error, "invalid entity"}

      %Entity{id: :virtual} ->
        delete_virtual_entity(entity)

      _ ->
        delete_stored_entity(entity)
    end
  end

  defp delete_virtual_entity(%Entity{key: nil}) do
    {:error, "cannot remove virtual entity with no key"}
  end

  defp delete_virtual_entity(entity) do
    Cachex.del(:px_cache, entity.key)
  end

  defp delete_stored_entity(entity) do
    case Repo.get(Record.Entity, entity.id) do
      nil ->
        :error

      record ->
        Repo.delete(record)

        Cachex.del(:px_cache, entity.id)

        if entity.key do
          Cachex.del(:px_cache, entity.key)
        end

        :ok
    end
  end

  defp cache_entity(%Entity{} = entity) do
    entity
    |> maybe_cache_entity_id()
    |> maybe_cache_entity_key()
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

  defp cache_entity_attributes(%Record.Entity{attributes: attributes} = entity)
       when is_list(attributes) do
    for attribute <- attributes do
      Cachex.put(:px_cache, {:attribute, entity.id, attribute.name}, attribute.id)
    end

    entity
  end

  defp cache_entity_attributes(%Record.Entity{} = entity), do: entity

  defp cache_entity_methods(%Record.Entity{methods: methods} = entity)
       when is_list(methods) do
    for method <- methods do
      Cachex.put(:px_cache, {:method, entity.id, method.name}, method.id)
    end

    entity
  end

  defp cache_entity_methods(%Record.Entity{} = entity), do: entity

  defp set_entity_attribute(%Entity{id: :virtual} = entity, name, value) do
    attributes = Map.put(entity.attributes, name, value)

    %{entity | attributes: attributes}
    |> cache_entity()
  end

  defp set_entity_attribute(%Entity{attributes: attributes} = entity, name, value) do
    case Map.fetch(attributes, name) do
      :error ->
        create_entity_attribute_value(entity, name, value)

      {:ok, former_value} ->
        set_entity_attribute_value(entity, name, value, former_value)
    end
  end

  defp create_entity_attribute_value(%Entity{} = entity, name, value) do
    attrs = %{entity_id: entity.id, name: name, value: :erlang.term_to_binary(value)}

    %Record.Attribute{}
    |> Record.Attribute.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, attribute} ->
        Cachex.put(:px_cache, {:attribute, entity.id, attribute.name}, attribute.id)

        %{entity | attributes: Map.put(entity.attributes, name, value)}
        |> cache_entity()

      error ->
        error
    end
  end

  defp set_entity_attribute_value(%Entity{} = entity, name, value, former) do
    case Cachex.get(:px_cache, {:attribute, entity.id, name}) do
      {:ok, nil} ->
        create_entity_attribute_value(entity, name, value)

      {:ok, attribute_id} ->
        serialized = :erlang.term_to_binary(value)

        if :erlang.term_to_binary(former) != serialized do
          Repo.get(Record.Attribute, attribute_id)
          |> Record.Attribute.changeset(%{value: serialized})
          |> Repo.update()
        end

        %{entity | attributes: Map.put(entity.attributes, name, value)}
        |> cache_entity()
    end
  end

  defp set_entity_method(%Entity{id: :virtual} = entity, name, code) do
    method = %Pythelix.Method{name: name, code: code}
    methods = Map.put(entity.methods, name, method)

    %{entity | methods: methods}
    |> cache_entity()
  end

  defp set_entity_method(%Entity{methods: methods} = entity, name, code) do
    case Map.fetch(methods, name) do
      :error ->
        create_entity_method_code(entity, name, code)

      {:ok, _} ->
        set_entity_method_code(entity, name, code)
    end
  end

  defp create_entity_method_code(%Entity{} = entity, name, code) do
    attrs = %{entity_id: entity.id, name: name, value: code}

    %Record.Method{}
    |> Record.Method.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, method} ->
        Cachex.put(:px_cache, {:method, entity.id, method.name}, method.id)
        entity_method = %Pythelix.Method{name: name, code: code}

        %{entity | methods: Map.put(entity.methods, name, entity_method)}
        |> cache_entity()

      error ->
        error
    end
  end

  defp set_entity_method_code(%Entity{} = entity, name, code) do
    case Cachex.get(:px_cache, {:method, entity.id, name}) do
      {:ok, nil} ->
        create_entity_method_code(entity, name, code)

      {:ok, method_id} ->
        Repo.get(Record.Method, method_id)
        |> Record.Method.changeset(%{value: code})
        |> Repo.update()

        method = %Pythelix.Method{name: name, code: code}

        %{entity | methods: Map.put(entity.methods, name, method)}
        |> cache_entity()
    end
  end
end
