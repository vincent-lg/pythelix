defmodule Pythelix.SubEntity do
  @moduledoc """
  A Pythelix sub entity with dynamic data.
  """

  alias Pythelix.Entity
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.SubEntity

  defstruct [:base, data: Dict.new()]

  @type t() :: %{
          base: Entity.t(),
          data: Dict.t()
        }

  @doc """
  Create a sub entity.
  """
  @spec new(Entity.t(), map() | Dict.t()) :: t() | {:error, String.t()}
  def new(base, data \\ Dict.new()) do
    case data do
      %Dict{} ->
        %SubEntity{base: base, data: data}

      map when is_map(map) ->
        %SubEntity{base: base, data: Dict.new(data)}

      _ ->
        {:error, "invalid data"}
    end
  end
end
