defmodule Pythelix.Scripting.Callable.SubMethod do
  @doc """
  Small wrapper around an sub-entity method.
  """

  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict

  defstruct [:entity, :sub, :name, :method]

  @type t() :: %{
          entity: binary() | integer(),
          sub: Pythelix.SubEntity.t(),
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

    kwargs =
      case kwargs do
        %Dict{} -> kwargs
        map when is_map(map) -> Dict.new(map)
        nil -> Dict.new()
      end
      |> then(& Dict.put(&1, "self", method.sub))
    Pythelix.Method.call(method.method, args, kwargs, name, opts)
  end
end
