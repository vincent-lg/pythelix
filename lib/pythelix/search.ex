defmodule Pythelix.Search do
  import Ecto.Query
  alias Pythelix.Repo
  alias Pythelix.Record
  alias Pythelix.Record.{Entity, Attribute}

  def find_many(filters) when is_list(filters) do
    # Get number of filters
    filter_count = length(filters)

    # Prepare binary match values
    encoded_filters =
      for {k, v} <- filters do
        {to_string(k), :erlang.term_to_binary(v)}
      end

    # Build subquery matching all filters
    # Build dynamic OR clause for attribute matching
    conditions =
      Enum.reduce(encoded_filters, false, fn
        {k, v}, false -> dynamic([a], a.name == ^k and a.value == ^v)
        {k, v}, dyn -> dynamic([a], a.name == ^k and a.value == ^v or ^dyn)
      end)

    # Subquery: filter attributes matching any (name, value) pair
    subquery =
      from a in Attribute,
        where: ^conditions,
        group_by: a.entity_gen_id,
        having: count(a.gen_id) == ^filter_count,
        select: a.entity_gen_id

    # Main query: get the entities whose attributes matched
    query =
      from e in Entity,
        where: e.gen_id in subquery(subquery),
        select: %{id: e.gen_id}

    Repo.all(query)
    |> Enum.map(fn %{id: id} -> Record.get_entity(id) end)
  end
end
