defmodule Pythelix.Record.Entity do
  use Ecto.Schema
  import Ecto.Changeset
  alias Pythelix.Record.Entity

  schema "entities" do
    field :key, :string
    field :methods, :binary
    belongs_to :location, Entity, foreign_key: :location_id
    belongs_to :parent, Entity, foreign_key: :parent_id
    has_many :attributes, Pythelix.Record.Attribute
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:key, :location_id, :parent_id, :methods])
    |> validate_required([])
  end

  def put_methods(changeset, method_map) when is_map(method_map) do
    serialized = :erlang.term_to_binary(method_map)
    put_change(changeset, :methods, serialized)
  end

  def get_methods(%__MODULE__{methods: nil}), do: %{}
  def get_methods(%__MODULE__{methods: binary}) do
    :erlang.binary_to_term(binary)
  end
end
