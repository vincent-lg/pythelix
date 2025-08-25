defmodule Pythelix.Command.DebugTest do
  use Pythelix.DataCase, async: false

  alias Pythelix.Command.Handler
  alias Pythelix.Game.Hub
  alias Pythelix.Record

  setup_all do
    # Command Hub needs to be global for TCP client send to work
    case GenServer.start_link(Pythelix.Command.Hub, [], name: {:global, Pythelix.Command.Hub}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Game hub might already be started (local)
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    # Create the missing generic/client entity manually
    case Record.get_entity("generic/client") do
      nil ->
        {:ok, _} =
          Record.create_entity(key: "generic/client", virtual: true)
          Record.set_attribute("generic/client", "msg", {:extended, Pythelix.Test.TestClientNamespace, :m_msg})
        :ok

      _ ->
        :ok
    end
  end

  test "debug direct network send" do
    # Create a test client entity
    {:ok, client} = Record.create_entity(key: "test_client", virtual: true)
    Record.set_attribute("test_client", "client_id", 999)
    Record.set_attribute("test_client", "pid", self())

    # Test direct network send
    Pythelix.Network.TCP.Client.send(client, "Direct network test!")

    # Check for message
    receive do
      {:message, msg} ->
        assert msg == "Direct network test!"
      other ->
        flunk("Unexpected message: #{inspect(other)}")
    after 2000 ->
      Process.info(self(), :messages)
      flunk("No network message received")
    end
  end

  test "debug command lookup and execution" do
    # Create a test client entity
    generic = Record.get_entity("generic/client")
    {:ok, client} = Record.create_entity(key: "test_client", virtual: true, parent: generic)
    Record.set_attribute("test_client", "client_id", 999)
    Record.set_attribute("test_client", "pid", self())
    Record.set_attribute("test_client", "location", "menu/test")

    # Create a test menu entity
    {:ok, menu} = Record.create_entity(key: "menu/test", virtual: true)
    Record.set_attribute("menu/test", "commands", %{
      "debug" => "command/debug"
    })

    # Create a simple debug command
    {:ok, _} = Record.create_entity(key: "command/debug", virtual: true)
    {_, args} = Pythelix.Command.Signature.constraints("run(client)")
    Record.set_method("command/debug", "run", args, "client.msg('Debug message!')")

    assert Record.get_entity("test_client") != nil
    assert Record.get_entity("menu/test") != nil
    assert Record.get_entity("command/debug") != nil

    # Execute command
    Handler.handle("debug", client, menu, System.monotonic_time(:microsecond))

    # Check for message
    receive do
      {:message, msg} ->
        assert msg == "Debug message!"
      other ->
        flunk("Unexpected message: #{inspect(other)}")
    after 2000 ->
      # Check mailbox
      Process.info(self(), :messages)
      flunk("No message received after 2000ms")
    end
  end
end
