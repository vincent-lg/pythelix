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

    key =
      case entity do
        %{key: key} when key != nil -> "!#{key}!"
        _ -> "##{entity.id}"
      end

    name = "#{key}, method #{method.name}"
    Pythelix.Method.call(method.method, args, kwargs, name, opts)
  end
end
