defmodule Pythelix.Entity do
  @moduledoc """
  A Pythelix entity with an ID, location, parent, attributes and methods.

  See `Pythelix.Record` for a context to manipulate the entity in database.
  """

  @enforce_keys [:id, :location_id]
  defstruct [:id, :parent_id, :location_id, key: nil]

  @type t() :: %{
          id: integer() | :virtual,
          key: binary() | nil,
          parent_id: integer() | binary() | nil,
          location_id: integer() | binary() | nil
        }

  @doc """
  Create an entity from a database record.
  """
  @spec new(struct()) :: t()
  def new(%Pythelix.Record.Entity{} = entity, key \\ nil) do
    %Pythelix.Entity{
      id: entity.gen_id,
      key: key,
      parent_id: entity.parent_id,
      location_id: entity.location_id
    }
  end

  def get_id_or_key(entity) do
    (entity.id != :virtual && entity.id) || entity.key
  end

  defimpl Inspect do
    import Inspect.Algebra

    alias Pythelix.Entity

    def inspect(%Entity{id: id, key: key}, _opts) do
      header = (key && "!") || "Entity(id="
      footer = (key && "!") || ")"

      concat([
        header,
        to_string(key || id),
        footer
      ])
    end
  end
end
