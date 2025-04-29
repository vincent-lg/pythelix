defmodule Pythelix.Entity do
  @moduledoc """
  A Pythelix entity with an ID, location, parent, attributes and methods.

  See `Pythelix.Record` for a context to manipulate the entity in database.
  """

  @enforce_keys [:id, :location_id]
  defstruct [:id, :parent_id, :location_id, key: nil, attributes: %{}, methods: %{}]

  @type t() :: %{
          id: integer() | :virtual,
          key: binary() | nil,
          parent_id: integer() | binary() | nil,
          location_id: integer() | binary() | nil,
          attributes: map(),
          methods: map()
        }

  @doc """
  Create an entity from a database record.
  """
  @spec new(struct()) :: t()
  def new(%Pythelix.Record.Entity{} = entity, key \\ nil) do
    %Pythelix.Entity{
      id: entity.id,
      key: key,
      parent_id: entity.parent_id,
      location_id: entity.location_id,
      attributes: new_attributes(entity.attributes),
      methods: new_methods(entity.methods)
    }
  end

  defp new_attributes(attributes) when is_list(attributes) do
    Map.new(attributes, fn attribute ->
      {attribute.name, :erlang.binary_to_term(attribute.value)}
    end)
  end

  defp new_attributes(_), do: %{}

  defp new_methods(methods) when is_list(methods) do
    Map.new(methods, fn method ->
      {method.name, %Pythelix.Method{name: method.name, code: method.value}}
    end)
  end

  defp new_methods(_), do: %{}

  def get_id_or_key(entity) do
    (entity.id != :virtual && entity.id) || entity.key
  end
end
