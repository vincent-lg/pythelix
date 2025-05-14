defmodule Pythelix.Record.Attribute do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:gen_id, :integer, []}

  schema "attributes" do
    #field :gen_id, :integer, primary_key: true
    field :name, :string
    field :value, :binary
    belongs_to :entity, Pythelix.Record.Entity, foreign_key: :entity_gen_id, references: :gen_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attribute, attrs) do
    attribute
    |> cast(attrs, [:gen_id, :name, :value, :entity_gen_id])
    |> validate_required([:gen_id, :name, :value, :entity_gen_id])
    |> unique_constraint(:name, name: :unique_entity_attribute)
  end
end
