defmodule Pythelix.Record.Diff do
  @moduledoc """
  Module to keep track of diffs in a cache.

  Diffs are just here to indicate what changed in the cache (see
  `Pythelix.Record.Cache`) and need to be stored in the database.
  This module is meant to be optimized for inserts and updates in particular.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Pythelix.Record
  alias Pythelix.Repo
  require Logger

  @doc """
  Initializes the cache.
  """
  def init() do
    query =
      from g in Record.IDGenerator,
        select: %{type: g.type, current_id: g.current_id}

    Repo.all(query)
    |> Enum.map(fn map -> {map.type, map.current_id} end)
    |> Map.new()
    |> tap(fn map ->
      Cachex.put(:px_diff, :org_entities, Map.get(map, "entities", 1))
      Cachex.put(:px_diff, :entities, Map.get(map, "entities", 1))
    end)
    |> tap(fn map ->
      Cachex.put(:px_diff, :org_attributes, Map.get(map, "attributes", 1))
      Cachex.put(:px_diff, :attributes, Map.get(map, "attributes", 1))
    end)
  end

  @doc """
  Return and increment the ID generator for entities.
  """
  @spec get_entity_id() :: integer()
  def get_entity_id() do
    return_and_increment(:entities)
  end

  @doc """
  Return and increment the ID generator for attributes.
  """
  @spec get_attribute_id() :: integer()
  def get_attribute_id() do
    return_and_increment(:attributes)
  end

  @doc """
  Add a change diff.

  A diff is a tuple with:

    # Entity modifications (gen_id is :entities)
    {:add, gen_id, key, parent_id, location_id}
    {:update, gen_id, field_name, field_value}
    {:delete, gen_id}

    # Attribute modifications (gen_id is :attributes)
    {:addattr, gen_id, entity_id, attribute_name, attribute_value}
    {:setattr, gen_id, attribute_name, attribute_value}
    {:delattr, gen_id}

  It will try to compress these modifications into as little queries
  as possible. Additions are handled with `insert_all`, while updates
  are handled with a custom query with case statements.

  When identifiers are mentioned (entity ID or attribute ID),
  they must be understood as generated IDs, not database table IDs.
  It "usually" is the very same thing, but differences can be noted at times
  and they are not meant to be exactly similar.
  """
  def add({:add, gen_id, key, parent_id, location_id}) do
    add_diff(:add, {gen_id, key, parent_id, location_id})
  end

  def add({:update, gen_id, field_name, field_value}) do
    add_diff(:update, {gen_id, field_name, field_value})
  end

  def add({:delete, gen_id}) do
    add_diff(:delete, {gen_id})
  end

  def add({:addattr, entity_id, gen_id, attribute_name, attribute_value}) do
    add_diff(:addattr, {gen_id, entity_id, attribute_name, attribute_value})
  end

  def add({:setattr, gen_id, attribute_name, attribute_value}) do
    add_diff(:setattr, {gen_id, attribute_name, attribute_value})
  end

  def add({:delattr, gen_id}) do
    add_diff(:delattr, {gen_id})
  end

  @doc """
  Apply (and clear) the list of changes.

  This function should be called however regularly to sync the cache and
  database. By default, this function will be called each time
  a command or script executes (whether they were successful or not).
  """
  @spec apply() :: :ok
  def apply() do
    {:ok, keys} = Cachex.keys(:px_diff)

    entries =
      keys
      |> Enum.filter(fn
        {:add, _} -> true
        {:update, _} -> true
        {:delete, _} -> true
        {:addattr, _} -> true
        {:setattr, _} -> true
        {:delattr, _} -> true
        _other -> false
      end)
      |> Enum.map(fn key ->
        case Cachex.get(:px_diff, key) do
          {:ok, nil} -> {nil, nil}
          {:ok, value} -> {key, value}
        end
      end)

    # Entities (add, update, delete)
    Multi.new()
    |> Multi.run(:add_entities, fn _repo, _changes ->
      to_add_entities(entries)
      |> Enum.chunk_every(2_000)
      |> Enum.each(fn chunk ->
        Repo.insert_all(Record.Entity, chunk)
      end)

      # If new IDs have been generated.
      case get_update_entity_query() do
        {sql, params} -> Repo.query!(sql, params)
        _other -> nil
      end

      {:ok, :done}
    end)
    |> Multi.run(:update_entities, fn _repo, _changes ->
      to_update_entities(entries)
      |> Enum.chunk_every(4_000)
      |> Enum.each(fn chunk ->
        chunk
        |> Enum.reduce(%{}, fn map, acc -> Map.merge(map, acc) end)
        |> build_bulk_update_queries("entities")
        |> Enum.each(fn {sql, params} ->
          Repo.query!(sql, params)
        end)
      end)

      {:ok, :done}
    end)
    |> Multi.run(:delete_entities, fn _repo, _changes ->
      to_delete_entities(entries)
      |> Enum.chunk_every(10_000)
      |> Enum.each(fn chunk ->
        from(e in Record.Entity, where: e.gen_id in ^chunk)
        |> Repo.delete_all()
      end)

      {:ok, :done}
    end)
    # Attributes (add, update, delete)
    |> Multi.run(:add_attributes, fn _repo, _changes ->
      to_add_attributes(entries)
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn chunk ->
        Repo.insert_all(Record.Attribute, chunk)
      end)

      # If new IDs have been generated.
      case get_update_attribute_query() do
        {sql, params} -> Repo.query!(sql, params)
        _other -> nil
      end

      {:ok, :done}
    end)
    |> Multi.run(:update_attributes, fn _repo, _changes ->
      to_update_attributes(entries)
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn chunk ->
        chunk
        |> Enum.reduce(%{}, fn map, acc -> Map.merge(map, acc) end)
        |> build_bulk_update_queries("attributes")
        |> Enum.each(fn {sql, params} ->
          Repo.query!(sql, params)
        end)
      end)

      {:ok, :done}
    end)
    |> Multi.run(:delete_attributes, fn _repo, _changes ->
      to_delete_attributes(entries)
      |> Enum.chunk_every(10_000)
      |> Enum.each(fn chunk ->
        from(a in Record.Attribute, where: a.gen_id in ^chunk)
        |> Repo.delete_all()
      end)

      {:ok, :done}
    end)
    |> Repo.transaction()
    |> handle_apply(entries)
  end

  defp return_and_increment(entry) do
    Cachex.get(:px_diff, entry)
    |> then(fn {:ok, value} -> value end)
    |> tap(& Cachex.put(:px_diff, entry, &1 + 1))
  end

  defp add_diff(:update, {gen_id, field, value}) do
    Cachex.get_and_update(:px_diff, {:update, gen_id}, fn
      nil ->
        {:commit, %{field => value}}

      map ->
        map
        |> Map.put(field, value)
        |> then(& {:commit, &1})
    end)
  end

  defp add_diff(:setattr, {gen_id, name, value}) do
    Cachex.get_and_update(:px_diff, {:setattr, gen_id}, fn
      nil ->
        {:commit, %{name: name, value: value}}

      updates ->
        updates
        |> Map.merge(%{name: name, value: value})
        |> then(& {:commit, &1})
    end)
  end

  defp add_diff(operation, args) do
    gen_id = elem(args, 0)
    rest = Tuple.delete_at(args, 0)

    Cachex.put(:px_diff, {operation, gen_id}, rest)
  end

  # Apply entities.
  defp to_add_entities(entries) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries
    |> Enum.filter(fn {key, _value} -> match?({:add, _}, key) end)
    |> Enum.map(fn {{:add, gen_id}, {key, parent_id, location_id}} ->
      %{
        gen_id: gen_id,
        key: key,
        parent_id: parent_id,
        location_id: location_id,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp to_update_entities(entries) do
    entries
    |> Enum.filter(fn {key, _value} -> match?({:update, _}, key) end)
    |> Enum.map(fn {{:update, gen_id}, map} ->
      %{gen_id => map}
    end)
  end

  defp to_delete_entities(entries) do
    entries
    |> Enum.filter(fn {key, _value} -> match?({:delete, _}, key) end)
    |> Enum.map(fn {{:delete, gen_id}, _} -> gen_id end)
  end

  # Apply attributes.
  defp to_add_attributes(entries) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries
    |> Enum.filter(fn {key, _value} -> match?({:addattr, _}, key) end)
    |> Enum.map(fn {{:addattr, gen_id}, {entity_id, name, value}} ->
      %{
        gen_id: gen_id,
        entity_gen_id: entity_id,
        name: name,
        value: value,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp to_update_attributes(entries) do
    entries
    |> Enum.filter(fn {key, _value} -> match?({:setattr, _}, key) end)
    |> Enum.map(fn {{:setattr, gen_id}, map} ->
      %{gen_id => map}
    end)
  end

  defp to_delete_attributes(entries) do
    entries
    |> Enum.filter(fn {key, _value} -> match?({:delattr, _}, key) end)
    |> Enum.map(fn {{:delattr, gen_id}, _} -> gen_id end)
  end

  defp build_bulk_update_queries(changes, table, key_field \\ :gen_id) when is_map(changes) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    fields =
      changes
      |> Enum.map(fn {_, map} -> Map.put(map, :updated_at, now) end)
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    Enum.flat_map(fields, fn field ->
      # Collect all changes that have a value for this field
      mods_for_field =
        changes
        |> Enum.filter(fn {_id, g_changes} -> Map.has_key?(g_changes, field) end)

      # Skip if no updates for this field
      if mods_for_field == [] do
        []
      else
        case_clauses =
          Enum.map(mods_for_field, fn {id, g_changes} ->
            {"WHEN ? THEN ?", [id, Map.fetch!(g_changes, field)]}
          end)

        case_sql =
          case_clauses
          |> Enum.map(fn {sql, _} -> sql end)
          |> Enum.join(" ")
        params = Enum.flat_map(case_clauses, fn {_, values} -> values end)

        ids = Enum.map(mods_for_field, fn {id, _} -> id end)
        where_placeholders = Enum.map(ids, fn _ -> "?" end) |> Enum.join(", ")

        sql = """
        UPDATE #{table}
        SET #{field} = CASE #{key_field} #{case_sql} END
        WHERE #{key_field} IN (#{where_placeholders})
        """

        [{String.trim(sql), params ++ ids}]
      end
    end)
  end

  defp get_update_entity_query() do
    org =
      case Cachex.get(:px_diff, :org_entities) do
        {:ok, nil} -> nil
        {:ok, id} -> id
      end

    gen_id =
      case Cachex.get(:px_diff, :entities) do
        {:ok, nil} -> nil
        {:ok, id} -> id
      end

    if org == gen_id do
      nil
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      sql = """
      INSERT INTO id_generators (type, current_id, inserted_at, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(type) DO UPDATE
      SET current_id = excluded.current_id,
        updated_at = excluded.updated_at;
      """

      {sql, ["entities", gen_id, now, now]}
    end
  end

  defp get_update_attribute_query() do
    org =
      case Cachex.get(:px_diff, :org_attributes) do
        {:ok, nil} -> nil
        {:ok, id} -> id
      end

    gen_id =
      case Cachex.get(:px_diff, :attributes) do
        {:ok, nil} -> nil
        {:ok, id} -> id
      end

    if org == gen_id do
      nil
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      sql = """
      INSERT INTO id_generators (type, current_id, inserted_at, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(type) DO UPDATE
      SET current_id = excluded.current_id,
        updated_at = excluded.updated_at;
      """

      {sql, ["attributes", gen_id, now, now]}
    end
  end

  defp handle_apply({:ok, _}, entries) do
    for {key, _} <- entries do
      Cachex.del(:px_diff, key)
    end
  end

  defp handle_apply(result, _) do
    Logger.warning("An error occurred while applying the diff to the database. Clear the cache.")
    Pythelix.Record.Cache.clear()

    result
  end
end
