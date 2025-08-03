defmodule Pythelix.Scripting.Namespace.Module.Clients do
  @moduledoc """
  Module defining the clients module.
  """

  use Pythelix.Scripting.Module, name: "clients"

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Store

  deffun active(script, _namespace), [] do
    {script, active()}
  end

  deffun controlling(script, namespace), [
    {:entity, index: 0, type: :entity}
  ] do
    entity = Store.get_value(namespace.entity)
    id_or_key = Entity.get_id_or_key(entity)

    active()
    |> Enum.filter(fn client ->
      controls = Record.get_attribute(client, "controls")
      controls = Dict.get(controls.data, "__controls", MapSet.new())
      MapSet.member?(controls, id_or_key)
    end)
    |> then(& {script, &1})
  end

  deffun owning(script, namespace), [
    {:entity, index: 0, type: :entity}
  ] do
    entity = Store.get_value(namespace.entity)

    active()
    |> Enum.filter(fn client ->
      owner = Record.get_attribute(client, "__owner")
      owner == entity
    end)
    |> Enum.at(0, :none)
    |> then(& {script, &1})
  end

  defp active do
    client = Record.get_entity("generic/client")
    Record.get_children(client)
  end
end
