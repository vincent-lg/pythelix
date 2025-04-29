defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :string}
  ] do
    client = Script.get_value(script, namespace.self)
    pid = client.attributes["pid"]

    send(pid, {:message, namespace.text})

    {script, :none}
  end
end
