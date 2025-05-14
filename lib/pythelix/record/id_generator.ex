defmodule Pythelix.Record.IDGenerator do
  use Ecto.Schema
  import Ecto.Changeset

  schema "id_generators" do
    field :type, :string
    field :current_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(id_generator, attrs) do
    id_generator
    |> cast(attrs, [:type, :current_id])
    |> validate_required([:type, :current_id])
  end
end
