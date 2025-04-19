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
  def get_entity(key) when is_binary(key) do
    case Cachex.get(:px_cache, key) do
      {:ok, nil} ->
        case Repo.get_by(Record.Key, key: key) do
          nil -> nil
          %Record.Key{entity_id: entity_id} -> get_entity(entity_id)
        end

      {:ok, entity} -> entity
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
          nil -> nil
          %{entity: entity, key: key} ->
            entity =
              entity
              |> Repo.preload([:attributes, :methods])
              |> cache_entity_attributes()
              |> Entity.new(key)
              |> cache_entity()

            entity
        end

      {:ok, entity} -> entity
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
  @spec set_attribute(integer(), String.t(), any()) :: :ok | :invalid_entity
  def set_attribute(id, name, value) do
    case get_entity(id) do
      nil -> :invalid_entity
      entity -> set_entity_attribute(entity, name, value)
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

  defp from_cache_entity({:ok, entity}), do: entity
  defp from_cache_entity({:commit, entity}), do: entity
  defp from_cache_entity({:ignore, nil}), do: nil

  defp cache_entity(%Entity{} = entity) do
    Cachex.put(:px_cache, entity.id, entity)

    if entity.key do
      Cachex.put(:px_cache, entity.key, entity)
    end

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
end
