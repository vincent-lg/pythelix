defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace
  alias Pythelix.Entity
  alias Pythelix.Record

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :str}
  ] do
    client = Store.get_value(namespace.self)
    Pythelix.Network.TCP.Client.send(client, namespace.text)

    {script, :none}
  end

  defmet disconnect(script, namespace), [] do
    client = Store.get_value(namespace.self)
    Pythelix.Network.TCP.Client.disconnect(client)

    {script, :none}
  end

  def owner(_script, self) do
    entity = Store.get_value(self)

    Record.get_attribute(entity, "__owner", :none)
  end

  def owner(script, self, owner) do
    entity = Store.get_value(self)
    owner = Store.get_value(owner)

    case owner do
      :none ->
        Record.set_attribute(entity, "owner", nil)
        {script, :none}

      %Entity{} ->
        Record.set_attribute(Entity.get_id_or_key(entity), "__owner", owner)
        {script, :none}

      _ ->
        {Script.raise(script, TypeError, "owner should be an entity"), :none}
    end
  end
end
