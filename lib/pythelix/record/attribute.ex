defmodule Pythelix.Record.Attribute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attributes" do
    field :name, :string
    field :value, :binary
    belongs_to :entity, Pythelix.Record.Entity

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attribute, attrs) do
    attribute
    |> cast(attrs, [:name, :value, :entity_id])
    |> validate_required([:name, :value, :entity_id])
    |> unique_constraint(:name, name: :unique_entity_attribute)
  end
end
