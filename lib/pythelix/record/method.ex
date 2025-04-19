defmodule Pythelix.Record.Method do
  use Ecto.Schema
  import Ecto.Changeset

  schema "methods" do
    field :name, :string
    field :value, :string
    belongs_to :entity, Pythelix.Record.Entity

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(method, attrs) do
    method
    |> cast(attrs, [:name, :value, :entity_id])
    |> validate_required([:name, :value, :entity_id])
    |> unique_constraint(:name, name: :unique_entity_method)
  end
end
