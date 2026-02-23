defmodule Pythelix.Command.IntegrationTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Command.Handler
  alias Pythelix.Command.Signature
  alias Pythelix.Command.Syntax.Parser
  alias Pythelix.Game.Hub
  alias Pythelix.Record

  setup_all do
    # Start the Game Hub for new system
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()

    # Create test generic/client entity with test namespace
    case Record.get_entity("test_generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "test_generic/client", virtual: true)
        :ok
      _ ->
        :ok
    end

    # Create a test client entity with proper parent
    test_generic_client = Record.get_entity("test_generic/client")
    Record.set_attribute("test_generic/client", "msg", {:extended, Pythelix.Test.TestClientNamespace, :m_msg})
    Record.set_attribute("test_generic/client", "disconnect", {:extended, Pythelix.Test.TestClientNamespace, :m_disconnect})
    Record.set_attribute("test_generic/client", "owner", {:extended_property, Pythelix.Test.TestClientNamespace, :owner})

    {:ok, client} = Record.create_entity(key: "test_client", virtual: true, parent: test_generic_client)
    Record.set_attribute("test_client", "client_id", 999)  # Test client ID
    Record.set_attribute("test_client", "pid", self())
    Record.set_attribute("test_client", "location", "menu/test")

    # Create a test menu entity
    {:ok, menu} = Record.create_entity(key: "menu/test", virtual: true)
    Record.set_attribute("menu/test", "commands", %{
      "shout" => "command/shout",
      "get" => "command/get",
      "pause_test" => "command/pause_test"
    })

    {:ok, client: client, menu: menu}
  end

  # Helper function to run commands using the new handler system
  defp run_command_via_handler(client, menu, command_input) do
    Handler.handle(command_input, client, menu, System.monotonic_time(:microsecond))

    # Give the async system some time to process
    #Process.sleep(100)
  end

  describe "simple command execution" do
    test "executes command with no arguments", %{client: client, menu: menu} do
      # Create a simple shout command
      {:ok, _command} = Record.create_entity(key: "command/shout", virtual: true)
      {_, args} = Signature.constraints("run(client)")
      Record.set_method("command/shout", "run", args, "client.msg('You shout loudly!')")

      # Execute command using the new handler system
      run_command_via_handler(client, menu, "shout")

      # Wait for execution and verify message
      assert_receive {:message, "You shout loudly!"}, 1000
    end

    test "executes command with string argument", %{client: client, menu: menu} do
      # Create shout command with message argument
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<message>")

      {:ok, _command} = Record.create_entity(key: "command/shout", virtual: true)
      {_, args} = Signature.constraints("run(client, message)")
      Record.set_method("command/shout", "run", args,
        "client.msg(f'You shout: {message}')")

      # Set syntax pattern attribute
      Record.set_attribute("command/shout", "syntax_pattern", syntax_pattern)

      # Execute command with argument
      run_command_via_handler(client, menu, "shout Hello World!")

      # Verify execution
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Hello World!")
    end

    test "handles command with refine method", %{client: client, menu: menu} do
      # Create shout command with refine method
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<message>")

      {_, args} = Signature.constraints("refine(client, message)")
      {:ok, _command} = Record.create_entity(key: "command/shout", virtual: true)
      Record.set_method("command/shout", "refine", args,
        "message = message.upper()")
      Record.set_method("command/shout", "run", args,
        "client.msg(f'You shout: {message}')")

      Record.set_attribute("command/shout", "syntax_pattern", syntax_pattern)

      # Execute command
      run_command_via_handler(client, menu, "shout hello")

      # Verify refined message
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "HELLO")
    end
  end

  describe "complex command execution" do
    test "executes command with multiple arguments and keywords", %{client: client, menu: menu} do
      # Create get command with complex syntax: <object> from <container>
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<object> from <container>")

      {:ok, _command} = Record.create_entity(key: "command/get", virtual: true)
      {_, args} = Signature.constraints("run(client, object, container=None)")
      Record.set_method("command/get", "run", args,
        "client.msg(f'You take {object} from {container}.')")

      Record.set_attribute("command/get", "syntax_pattern", syntax_pattern)

      # Execute command
      run_command_via_handler(client, menu, "get red apple from treasure chest")

      # Verify execution
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "red apple")
      assert String.contains?(msg, "treasure chest")
    end

    test "handles optional arguments", %{client: client, menu: menu} do
      # Create get command with optional container: <object> (from <container>)
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<object> (from <container>)")

      {:ok, _command} = Record.create_entity(key: "command/get", virtual: true)
      {_, args} = Signature.constraints("run(client, object, container=None)")
      Record.set_method("command/get", "run", args,
        """
        if container:
            client.msg(f'You take {object} from {container}.')
        else:
            client.msg(f'You take {object} from the ground.')
        endif
        """)

      Record.set_attribute("command/get", "syntax_pattern", syntax_pattern)

      # Test with container
      run_command_via_handler(client, menu, "get sword from chest")
      assert_receive {:message, msg1}, 1000
      assert String.contains?(msg1, "from chest")

      # Test without container
      {:ok, _command} = Record.create_entity(key: "command/get2", virtual: true)
      Record.set_method("command/get2", "run", args,
        """
        if container:
            client.msg(f'You take {object} from {container}.')
        else:
            client.msg(f'You take {object} from the ground.')
        endif
        """)
      Record.set_attribute("command/get2", "syntax_pattern", syntax_pattern)

      # Update menu commands to include get2
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "get2", "command/get2")
      Record.set_attribute("menu/test", "commands", updated_commands)

      run_command_via_handler(client, menu, "get2 sword")
      assert_receive {:message, msg2}, 1000
      assert String.contains?(msg2, "from the ground")
    end

    test "handles parse errors gracefully", %{client: client, menu: menu} do
      # Create command with parse_error method
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<object> from <container>")

      {:ok, _} = Record.create_entity(key: "command/get", virtual: true)
      {_, args} = Signature.constraints("run(client, object, container=None)")
      Record.set_method("command/get", "run", args,
        "client.msg('Success!')")
      {_, args} = Signature.constraints("error(client, args)")
      Record.set_method("command/get", "parse_error", args,
        "client.msg('Usage: get <object> from <container>')")

      Record.set_attribute("command/get", "syntax_pattern", syntax_pattern)

      # Execute invalid command
      run_command_via_handler(client, menu, "get sword")

      # Verify error handling
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Usage:")
    end
  end

  describe "pause handling in commands" do
    test "command with pause continues execution", %{client: client, menu: menu} do
      # Create command with pause
      {:ok, _command} = Record.create_entity(key: "command/pause_test", virtual: true)
      {_, args} = Signature.constraints("run(client)")
      Record.set_method("command/pause_test", "run", args,
        """
        client.msg('Before pause')
        wait 1
        client.msg('After pause')
        """)

      # Execute command
      run_command_via_handler(client, menu, "pause_test")

      # Verify first message
      assert_receive {:message, "Before pause"}, 1000

      # Verify second message after pause
      assert_receive {:message, "After pause"}, 2000
    end

    test "command with multiple pauses", %{client: client, menu: menu} do
      # Create command with multiple pauses
      {:ok, _command} = Record.create_entity(key: "command/pause_test2", virtual: true)
      {_, args} = Signature.constraints("run(client)")
      Record.set_method("command/pause_test2", "run", args,
        """
        client.msg('Step 1')
        wait 1
        client.msg('Step 2')
        wait 1
        client.msg('Step 3')
        """)

      # Update menu commands to include pause_test2
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "pause_test2", "command/pause_test2")
      Record.set_attribute("menu/test", "commands", updated_commands)

      # Execute command
      run_command_via_handler(client, menu, "pause_test2")

      # Verify messages in sequence
      assert_receive {:message, "Step 1"}, 1000
      assert_receive {:message, "Step 2"}, 2000
      assert_receive {:message, "Step 3"}, 3000
    end

    test "refine method can use pause", %{client: client, menu: menu} do
      # Create command with pause in refine (should be avoided)
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<message>")

      {:ok, _} = Record.create_entity(key: "command/pause_test3", virtual: true)
      {_, args} = Signature.constraints("refine(client, message)")
      Record.set_method("command/pause_test3", "refine", args,
        """
        wait 1
        message = message.upper()
        """)
      Record.set_method("command/pause_test3", "run", args,
        "client.msg(f'Message: {message}')")

      Record.set_attribute("command/pause_test3", "syntax_pattern", syntax_pattern)

      # Update menu commands to include pause_test3
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "pause_test3", "command/pause_test3")
      Record.set_attribute("menu/test", "commands", updated_commands)

      # Execute command
      run_command_via_handler(client, menu, "pause_test3 hello")

      # Should execute immediately
      assert_receive {:message, msg}, 2000
      assert String.contains?(msg, "HELLO")
    end
  end

  # ---------------------------------------------------------------------------
  # Get command with search.match, location assignment, and names.group
  # Uses owner_entity pattern: a character entity owns the client and is
  # placed in the room. The character (not the client) is used as the
  # script's "client" variable when owner_entity is provided.

  describe "get command with search and display" do
    defp setup_get_command do
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("(#number#) <object>")
      {:ok, _command} = Record.create_entity(key: "command/get", virtual: true)
      Record.set_attribute("command/get", "syntax_pattern", syntax_pattern)

      {_, refine_args} = Signature.constraints("refine(client, object, number=1)")
      Record.set_method("command/get", "refine", refine_args,
        """
        to_pick = search.match(client.location, object, limit=number)
        """)

      {_, run_args} = Signature.constraints("run(client, to_pick)")
      Record.set_method("command/get", "run", run_args,
        """
        for item in to_pick:
            item.location = client
        done
        for name in names.group(to_pick):
            client.msg(f"You pick up {name}.")
        done
        """)
    end

    defp setup_character_in_room(room_key, char_key) do
      {:ok, room} = Record.create_entity(key: room_key, virtual: true)
      test_generic_client = Record.get_entity("test_generic/client")
      {:ok, character} = Record.create_entity(
        key: char_key, virtual: true, parent: test_generic_client, location: room)
      Record.set_attribute(char_key, "pid", self())
      {room, character}
    end

    test "get command with syntax (#number#) <object> searches and moves stackables",
         %{client: client, menu: _menu} do
      {room, character} = setup_character_in_room("get_test_room", "get_test_char")

      {:ok, _coin} = Record.create_entity(key: "get_test_coin", virtual: true)
      Record.set_attribute("get_test_coin", "stackable", true)
      Record.set_attribute("get_test_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("get_test_coin"), 100)

      setup_get_command()

      # Execute via handler with owner_entity (character)
      Handler.start_command_execution(
        "command/get", "10 gold coin", client,
        System.monotonic_time(:microsecond), character)

      assert_receive {:message, msg}, 2000
      assert String.contains?(msg, "You pick up")
      assert String.contains?(msg, "gold coin")

      coin = Record.get_entity("get_test_coin")
      assert Record.get_stackable_quantity(room, coin) == 90
      assert Record.get_stackable_quantity(character, coin) == 10
    end

    test "get command with no match produces no output (empty to_pick)",
         %{client: client, menu: _menu} do
      {_room, character} = setup_character_in_room("get_nf_room", "get_nf_char")

      setup_get_command()

      # Execute: "get sword" in an empty room — to_pick will be []
      # The run method's for loop over to_pick produces no iterations, so no messages.
      Handler.start_command_execution(
        "command/get", "sword", client,
        System.monotonic_time(:microsecond), character)

      refute_receive {:message, _}, 500
    end

    test "get command with optional number defaults to 1 (regular entity)",
         %{client: client, menu: _menu} do
      {room, character} = setup_character_in_room("get_def_room", "get_def_char")

      # A regular (non-stackable) apple placed in the room.
      # limit has no practical effect here since there is only one entity, but the
      # refine method signature default number=1 must be applied correctly.
      {:ok, apple} = Record.create_entity(
        key: "get_def_apple", virtual: true, location: room)
      Record.set_attribute("get_def_apple", "name", "apple")

      setup_get_command()

      # Execute: "get apple" (no number, defaults to 1 via method signature)
      Handler.start_command_execution(
        "command/get", "apple", client,
        System.monotonic_time(:microsecond), character)

      assert_receive {:message, msg}, 2000
      assert String.contains?(msg, "You pick up")
      assert String.contains?(msg, "apple")

      # The apple moved to character's inventory (room still contains the character entity)
      assert Record.get_location(apple) == character
      refute apple in Record.get_contained(room)
    end
  end

  describe "error handling" do
    test "handles missing run method", %{client: client, menu: menu} do
      # Create command without run method
      {:ok, _} = Record.create_entity(key: "command/shout_no_run", virtual: true)
      Record.set_method("command/shout_no_run", "refine", [], "# No run method")

      # Update menu commands to include shout_no_run
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "shout_no_run", "command/shout_no_run")
      Record.set_attribute("menu/test", "commands", updated_commands)

      # Execute command
      run_command_via_handler(client, menu, "shout_no_run")

      # Should receive error message
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "no run method")
    end

    test "handles refine errors", %{client: client, menu: menu} do
      # Create command with failing refine and refine_error handler
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("<message>")

      {:ok, _} = Record.create_entity(key: "command/shout_error", virtual: true)
      {_, args} = Signature.constraints("refine(client, message)")
      Record.set_method("command/shout_error", "refine", args,
        "unknown_variable")
      {_, e_args} = Signature.constraints("refine_error(client, args)")
      Record.set_method("command/shout_error", "refine_error", e_args,
        "client.msg(f'Refine failed for: args')")
      Record.set_method("command/shout_error", "run", args,
        "client.msg('Success')")

      Record.set_attribute("command/shout_error", "syntax_pattern", syntax_pattern)

      # Update menu commands to include shout_error
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "shout_error", "command/shout_error")
      Record.set_attribute("menu/test", "commands", updated_commands)

      # Execute command
      run_command_via_handler(client, menu, "shout_error test")

      # Should handle refine error
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Refine failed")
    end
  end

  describe "command attributes and syntax" do
    test "command with integer arguments", %{client: client, menu: menu} do
      # Create command with integer syntax
      {:ok, syntax_pattern, "", _, _, _} = Parser.syntax("#times# <message>")

      {:ok, _} = Record.create_entity(key: "command/shout_repeat", virtual: true)
      {_, args} = Signature.constraints("run(client, times, message)")
      Record.set_method("command/shout_repeat", "run", args,
        """
        i = 0
        while i < times:
            client.msg(f'{i + 1}: {message}')
            i = i + 1
        done
        """)

      Record.set_attribute("command/shout_repeat", "syntax_pattern", syntax_pattern)

      # Update menu commands to include shout_repeat
      existing_commands = Record.get_attribute(menu, "commands")
      updated_commands = Map.put(existing_commands, "shout_repeat", "command/shout_repeat")
      Record.set_attribute("menu/test", "commands", updated_commands)

      # Execute command
      run_command_via_handler(client, menu, "shout_repeat 3 Hello!")

      # Verify multiple messages
      assert_receive {:message, msg1}, 1000
      assert String.contains?(msg1, "1: Hello!")
      assert_receive {:message, msg2}, 1000
      assert String.contains?(msg2, "2: Hello!")
      assert_receive {:message, msg3}, 1000
      assert String.contains?(msg3, "3: Hello!")
    end
  end
end
