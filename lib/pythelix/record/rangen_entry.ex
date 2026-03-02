defmodule Pythelix.Record.RangenEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rangen_entries" do
    field :generator_key, :string
    field :value, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:generator_key, :value])
    |> validate_required([:generator_key, :value])
    |> unique_constraint([:generator_key, :value])
  end
end
