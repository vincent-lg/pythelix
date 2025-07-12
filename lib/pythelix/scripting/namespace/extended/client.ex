defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace

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
end
