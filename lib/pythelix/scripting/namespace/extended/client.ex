defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Record
  alias Pythelix.Scripting.Format

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :string}
  ] do
    client = Script.get_value(script, namespace.self)
    pid = Record.get_attribute(client, "pid")

    message = Format.String.format(namespace.text)

    send(pid, {:message, message})

    {script, :none}
  end
end
