defmodule Pythelix.Game.MessageIntegrationTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Command.Signature
  alias Pythelix.Game.Hub
  alias Pythelix.Network.TCP.Server
  alias Pythelix.Record

  @test_port 4000  # Use the default port from the server

  setup_all do
    # Start the Game Hub
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Start the TCP Client Supervisor (required by server)
    case DynamicSupervisor.start_link(strategy: :one_for_one, name: Pythelix.Network.TCP.ClientSupervisor) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Start the TCP server (it uses hard-coded port 4000)
    case Server.start_link(nil) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Give the server a moment to start listening
    Process.sleep(100)
    :ok
  end

  setup do
    # Load the static worldlet
    Pythelix.World.apply(:static)

    # Ensure we have required entities
    setup_generic_entities()

    # Create test menus with prompts
    setup_test_menus()

    # Create a simple test command that sends messages
    setup_test_commands()

    :ok
  end

  defp setup_generic_entities do
    # Create generic/client if it doesn't exist
    case Record.get_entity("generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "generic/client", virtual: true)
      _ ->
        :ok
    end

    # Set up extended client methods to use our Game Hub system
    Record.set_attribute("generic/client", "msg", {:extended, Pythelix.Scripting.Namespace.Extended.Client, :m_msg})
    Record.set_attribute("generic/client", "disconnect", {:extended, Pythelix.Scripting.Namespace.Extended.Client, :m_disconnect})

    # Create generic/menu if needed
    case Record.get_entity("generic/menu") do
      nil ->
        {:ok, _} = Record.create_entity(key: "generic/menu", virtual: true)
      _ ->
        :ok
    end

    # Create generic/command if needed
    case Record.get_entity("generic/command") do
      nil ->
        {:ok, _} = Record.create_entity(key: "generic/command", virtual: true)
      _ ->
        :ok
    end

    # Create SubEntity and Controls entities (required for client initialization)
    case Record.get_entity("SubEntity") do
      nil ->
        {:ok, _} = Record.create_entity(key: "SubEntity", virtual: true)
      _ ->
        :ok
    end

    case Record.get_entity("Controls") do
      nil ->
        {:ok, _} = Record.create_entity(key: "Controls", virtual: true, parent: Record.get_entity("SubEntity"))
        # Add basic __init__ method for Controls
        {_, args} = Signature.constraints("__init__()")
        Record.set_method("Controls", "__init__", args, "")
      _ ->
        :ok
    end
  end

  defp setup_test_menus do
    # Create MOTD menu that clients connect to initially
    #{:ok, _} = Record.create_entity(key: "menu/motd", virtual: true, parent: Record.get_entity("generic/menu"))
    Record.set_attribute("menu/motd", "text", "Welcome to Test MUD!")

    # Set up get_prompt method
    {_, args} = Signature.constraints("get_prompt(client)")
    Record.set_method("menu/motd", "get_prompt", args, "return '[MOTD] > '")

    # Create a game menu with different prompt
    #{:ok, _} = Record.create_entity(key: "menu/game", virtual: true, parent: Record.get_entity("generic/menu"))
    Record.set_attribute("menu/game", "text", "You are now in the game!")
    Record.set_method("menu/game", "get_prompt", args, "return '[Game] > '")
  end

  defp setup_test_commands do
    # Create a test command that sends multiple messages
    {:ok, command} = Record.create_entity(key: "command/test", virtual: true, parent: Record.get_entity("generic/command"))
    Record.change_location(command, Record.get_entity("menu/motd"))
    Record.set_attribute("command/test", "name", "test")
    Record.set_attribute("menu/motd", "commands", %{
      "test" => "command/test"
    })

    {_, args} = Signature.constraints("run(client)")
    Record.set_method("command/test", "run", args,
      """
      client.msg("First test message")
      client.msg("Second test message")
      client.msg("Third test message")
      """)

    # Create a command with pauses
    {:ok, _} = Record.create_entity(key: "command/slow", virtual: true, parent: Record.get_entity("generic/command"))
    Record.set_attribute("command/slow", "location", "menu/motd")
    Record.set_attribute("command/slow", "name", "slow")

    Record.set_method("command/slow", "run", args,
      """
      client.msg("Starting slow command...")
      wait 0.1
      client.msg("Middle of slow command...")
      wait 0.1
      client.msg("Finished slow command!")
      """)

    # Update menu commands
    Record.set_attribute("menu/motd", "commands", %{
      "test" => "command/test",
      "slow" => "command/slow"
    })
  end

  describe "TCP client message integration" do
    test "client connects and receives welcome message with prompt (validates Game Hub message system)" do
      # Connect TCP client with active mode for non-blocking message reception
      {:ok, socket} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])

      # Should receive welcome message and then prompt (Game Hub message queuing system)
      assert_receive {:tcp, ^socket, welcome_response}, 1000
      assert String.contains?(welcome_response, "Welcome to Test MUD!")

      # The prompt might be sent separately or together - let's handle both cases
      if !String.contains?(welcome_response, "[MOTD] >") do
        # Prompt sent separately - this is also valid behavior
        assert_receive {:tcp, ^socket, prompt_response}, 1000
        assert String.contains?(prompt_response, "[MOTD] >")
      end

      # Send any command to test job completion
      :gen_tcp.send(socket, "test\r\n")

      # Should get a response after Game Hub processes the job
      assert_receive {:tcp, ^socket, response}, 1000
      assert response != ""

      :gen_tcp.close(socket)
    end

    test "grouped commands send multiple messages together" do
      # Connect with active mode for non-blocking reception
      {:ok, socket} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])

      # Clear welcome message
      welcome = receive_all(socket, 100)
      assert String.contains?(welcome, "Welcome to Test MUD!")

      # Send test command that generates multiple messages
      :gen_tcp.send(socket, "test\r\n")

      # Collect all messages that arrive within a time window
      messages = collect_tcp_messages(socket, 800, []) # 800ms timeout to collect grouped messages

      # Should receive the 3 test messages plus a prompt
      assert length(messages) == 4
      assert Enum.any?(messages, &String.contains?(&1, "First test message"))
      assert Enum.any?(messages, &String.contains?(&1, "Second test message"))
      assert Enum.any?(messages, &String.contains?(&1, "Third test message"))
      assert Enum.any?(messages, &String.contains?(&1, "[MOTD] >"))

      :gen_tcp.close(socket)
    end

    test "Game Hub message queuing system works with job completion" do
      {:ok, socket} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])

      # Clear welcome message
      receive_all(socket, 200)

      # Send command - regardless of whether it executes, the Game Hub should process it
      :gen_tcp.send(socket, "any_command\r\n")

      # Should receive a prompt response, proving the Game Hub job completion system works
      response = receive_all(socket, 500)
      assert String.contains?(response, "[MOTD] >")

      :gen_tcp.close(socket)
    end

    test "multiple client connections each get their own message queuing" do
      # Connect two clients
      {:ok, socket1} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])
      {:ok, socket2} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])

      # Both should get welcome messages independently
      assert_receive {:tcp, ^socket1, welcome1}, 1000
      assert_receive {:tcp, ^socket2, welcome2}, 1000

      assert String.contains?(welcome1, "Welcome to Test MUD!")
      assert String.contains?(welcome2, "Welcome to Test MUD!")

      :gen_tcp.close(socket1)
      :gen_tcp.close(socket2)
    end
  end

  describe "error handling" do
    test "Game Hub handles errors gracefully" do
      # Set up a menu with broken get_prompt to test error handling
      {_, args} = Signature.constraints("get_prompt(client)")
      Record.set_method("menu/motd", "get_prompt", args, "undefined_variable")

      {:ok, socket} = :gen_tcp.connect(~c"localhost", @test_port, [:binary, packet: :line, active: true])

      # Should still receive welcome message even with broken prompt
      assert_receive {:tcp, ^socket, welcome}, 1000
      assert String.contains?(welcome, "Welcome to Test MUD!")

      # Game Hub should handle the broken prompt gracefully
      :gen_tcp.close(socket)
    end
  end

  # Helper function to collect TCP messages with timeout
  defp receive_all(socket, timeout) do
    collect_tcp_messages(socket, timeout)
    |> Enum.join("\r\n")
  end

  defp collect_tcp_messages(socket, timeout, acc \\ []) do
    receive do
      {:tcp, ^socket, data} ->
        # Continue collecting with same timeout
        collect_tcp_messages(socket, timeout, [String.trim(data) | acc])
    after
      timeout ->
        Enum.reverse(acc)
    end
  end
end
