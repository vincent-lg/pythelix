defmodule Pythelix.Test.TestClientNamespace do
  @moduledoc """
  Test namespace for client that sends messages directly to test process
  without going through the Command Hub system.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Record
  alias Pythelix.Scripting.Format

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :str}
  ] do
    client = Store.get_value(namespace.self)

    # Get the test process PID and send message directly
    text = Format.String.format(namespace.text)
    test_pid = Record.get_attribute(client, "pid")
    send(test_pid, {:message, text})

    {script, :none}
  end

  defmet disconnect(script, namespace), [] do
    client = Store.get_value(namespace.self)
    test_pid = Record.get_attribute(client, "pid")
    send(test_pid, :disconnect)

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

      %Pythelix.Entity{} ->
        Record.set_attribute(Pythelix.Entity.get_id_or_key(entity), "__owner", owner)
        {script, :none}

      _ ->
        {Pythelix.Scripting.Interpreter.Script.raise(script, TypeError, "owner should be an entity"), :none}
    end
  end
end