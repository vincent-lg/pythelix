defmodule Pythelix.Scripting.Callable.Method do
  @doc """
  Small wrapper around an entity and a method.
  """

  alias Pythelix.Record

  defstruct [:entity, :name, :method]

  @type t() :: %{
          entity: binary() | integer(),
          name: String.t(),
          method: Pythelix.Method.t()
        }

  def call(method, args, kwargs, opts \\ []) do
    entity = Record.get_entity(method.entity)
    name = Pythelix.Method.label(method.method, entity, method.name)

    Pythelix.Method.call(method.method, args, kwargs, name, opts)
  end
end
