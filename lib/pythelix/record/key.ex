defmodule Pythelix.Record.Key do
  use Ecto.Schema
  import Ecto.Changeset

  schema "keys" do
    field :key, :string
    belongs_to :entity, Pythelix.Record.Entity
  end

  @doc false
  def changeset(key, attrs) do
    key
    |> cast(attrs, [:entity_id, :key])
    |> validate_required([:entity_id, :key])
  end
end
