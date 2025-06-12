defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Record
  alias Pythelix.Scripting.Format

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :str}
  ] do
    client = Script.get_value(script, namespace.self)
    client_id = Record.get_attribute(client, "client_id")
    pid = Record.get_attribute(client, "pid")
    message = Format.String.format(namespace.text)
    GenServer.cast({:global, Pythelix.Command.Hub}, {:message, client_id, message, pid})

    {script, :none}
  end
end
