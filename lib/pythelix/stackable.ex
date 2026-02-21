defmodule Pythelix.Stackable do
  @moduledoc """
  A stackable handle representing N of an entity at a specific location.

  Instead of creating 150 gold coin entities, a single gold_coin entity
  can appear in multiple containers with different quantities.
  """

  alias Pythelix.Entity

  defstruct [:entity, :quantity, :location]

  @type t() :: %{
          entity: Entity.t(),
          quantity: integer(),
          location: Entity.t() | nil
        }

  def get_id_or_key(%__MODULE__{entity: entity}) do
    Entity.get_id_or_key(entity)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Pythelix.Stackable{entity: entity, quantity: qty}, _opts) do
      key = entity.key || entity.id
      concat(["Stackable(", to_string(key), ", x", to_string(qty), ")"])
    end
  end
end
