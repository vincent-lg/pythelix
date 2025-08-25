defmodule Pythelix.TestNamespace do
  use Pythelix.DataCase, async: false

  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Runner
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Game.Hub

  setup_all do
    # Start Game Hub for new system
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    # Create test generic/client entity with test namespace
    case Record.get_entity("test_generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "test_generic/client", virtual: true)
        Record.set_attribute("test_generic/client", "msg", {:extended, Pythelix.Test.TestClientNamespace, :m_msg})
        Record.set_attribute("test_generic/client", "disconnect", {:extended, Pythelix.Test.TestClientNamespace, :m_disconnect})
        Record.set_attribute("test_generic/client", "owner", {:extended_property, Pythelix.Test.TestClientNamespace, :owner})
        :ok
      _ ->
        :ok
    end

    # Create a test client entity with proper parent
    test_generic_client = Record.get_entity("test_generic/client")
    {:ok, client} = Record.create_entity(key: "test_namespace_client", virtual: true, parent: test_generic_client)
    Record.set_attribute("test_namespace_client", "client_id", 998)
    Record.set_attribute("test_namespace_client", "pid", self())

    {:ok, client: client}
  end

  test "test namespace works with Runner", %{client: client} do
    # Create script with client variable
    code = "client.msg('Test namespace message')"
    name = "test namespace script"
    script = Scripting.run(code, call: false)
    script = Script.write_variable(script, "client", client)

    # Execute script with client.msg call
    Runner.run(script, code, name)

    # Wait for execution and verify message
    receive do
      msg ->
        assert {:message, "Test namespace message"} = msg
    after
      2000 ->
        assert false, "No message received from test namespace"
    end
  end
end
