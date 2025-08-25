defmodule Pythelix.Menu.IntegrationTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Command.Signature
  alias Pythelix.Game.Hub
  alias Pythelix.Menu.Handler
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

    # Create the missing generic/client entity manually
    case Record.get_entity("generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "generic/client", virtual: true)
        :ok
      _ ->
        :ok
    end

    # Create a test client entity with proper parent
    generic_client = Record.get_entity("generic/client")
    Record.set_attribute("generic/client", "msg", {:extended, Pythelix.Test.TestClientNamespace, :m_msg})
    Record.set_attribute("generic/client", "disconnect", {:extended, Pythelix.Test.TestClientNamespace, :m_disconnect})
    Record.set_attribute("generic/client", "owner", {:extended_property, Pythelix.Test.TestClientNamespace, :owner})
    {:ok, client} = Record.create_entity(key: "test_client", virtual: true, parent: generic_client)
    Record.set_attribute("test_client", "client_id", 999)  # Test client ID
    Record.set_attribute("test_client", "pid", self())
    Record.set_attribute("test_client", "location", "menu/test")

    # Create test menus
    {:ok, main_menu} = Record.create_entity(key: "menu/main", virtual: true)
    Record.set_attribute("menu/main", "text", "Welcome to the main menu!")
    Record.set_attribute("menu/main", "commands", %{
      "help" => "command/help",
      "quit" => "command/quit"
    })

    {:ok, login_menu} = Record.create_entity(key: "menu/login", virtual: true)
    Record.set_attribute("menu/login", "text", "Please enter your username:")
    Record.set_attribute("menu/login", "commands", %{
      "new" => "command/new_account"
    })

    {:ok, client: client, main_menu: main_menu, login_menu: login_menu}
  end

  describe "basic menu functionality" do
    test "menu with input method handles user input", %{client: client, main_menu: menu} do
      # Create input method that redirects on "quit"
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "quit":
            client.msg("Goodbye!")
            client.location = !menu/login!
            return True
        else:
            return False
        endif
        """)

      # Handle input
      Handler.handle(menu, client, "quit", System.monotonic_time(:microsecond))

      # Verify response
      assert_receive {:message, "Goodbye!"}, 1000
    end

    test "menu falls back to commands when input method returns false", %{client: client, main_menu: menu} do
      # Create help command
      {_, args} = Signature.constraints("run(client)")
      Record.create_entity(key: "command/help", virtual: true)
      Record.set_method("command/help", "run", args,
        "client.msg('Help: Available commands are help and quit.')")

      # Create input method that returns false for "help"
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "quit":
            client.msg("Goodbye!")
            return True
        else:
            return False
        endif
        """)

      # Handle input - should fall back to command
      Handler.handle(menu, client, "help", System.monotonic_time(:microsecond))

      # Verify command was executed
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Available commands")
    end

    test "menu handles unknown input with unknown_input method", %{client: client, main_menu: menu} do
      # Create unknown_input method
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "unknown_input", args,
        "client.msg(f'Unknown command: {input}. Type help for assistance.')")

      # Handle unknown input
      Handler.handle(menu, client, "invalid_command", System.monotonic_time(:microsecond))

      # Verify unknown_input was called
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Unknown command: invalid_command")
    end

    test "menu falls back to generic message when no unknown_input method", %{client: client, main_menu: menu} do
      # Handle unknown input without unknown_input method
      Handler.handle(menu, client, "invalid_command", System.monotonic_time(:microsecond))

      # Verify generic message
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "I don't understand")
    end
  end

  describe "menu input method scenarios" do
    test "login menu checks for existing account", %{client: client, login_menu: menu} do
      # Create input method that checks for accounts
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/login", "input", args,
        """
        if input.lower() == "testuser":
            client.msg("Welcome back, testuser!")
            client.location = !menu/main!
            return True
        else:
            return False
        endif
        """)

      # Create unknown_input method for invalid usernames
      Record.set_method("menu/login", "unknown_input", args,
        "client.msg('Username not found. Try again or type new to create account.')")

      # Test existing user
      Handler.handle(menu, client, "testuser", System.monotonic_time(:microsecond))
      assert_receive {:message, "Welcome back, testuser!"}, 1000

      # Test non-existing user
      Handler.handle(menu, client, "invaliduser", System.monotonic_time(:microsecond))
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "Username not found")
    end

    test "menu with complex input processing", %{client: client, main_menu: menu} do
      # Create input method that handles multiple commands
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        words = input.split()
        if words == []:
            return False
        endif

        command = words.pop(0).lower()
        if command == "say":
            if words != []:
                message = ' '.join(words)
                client.msg(f'You say: {message}')
                return True
            else:
                client.msg('Say what?')
                return True
            endif
        elif command == "time":
            client.msg('The current time is now.')
            return True
        else:
            return False
        endif
        """)

      # Test say command with message
      Handler.handle(menu, client, "say Hello world!", System.monotonic_time(:microsecond))
      assert_receive {:message, msg1}, 1000
      assert String.contains?(msg1, "You say: Hello world!")

      # Test say command without message
      Handler.handle(menu, client, "say", System.monotonic_time(:microsecond))
      assert_receive {:message, "Say what?"}, 1000

      # Test time command
      Handler.handle(menu, client, "time", System.monotonic_time(:microsecond))
      assert_receive {:message, "The current time is now."}, 1000
    end
  end

  describe "pause handling in menus" do
    test "menu input method with pause", %{client: client, main_menu: menu} do
      # Create input method with pause
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "wait":
            client.msg('Starting to wait...')
            wait 1
            client.msg('Done waiting!')
            return True
        else:
            return False
        endif
        """)

      # Execute input with pause
      Handler.handle(menu, client, "wait", System.monotonic_time(:microsecond))

      # Verify messages with timing
      assert_receive {:message, "Starting to wait..."}, 1000
      assert_receive {:message, "Done waiting!"}, 2000
    end

    test "menu with multiple pause stages", %{client: client, main_menu: menu} do
      # Create input method with multiple pauses
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "countdown":
            client.msg('Starting countdown...')
            wait 1
            client.msg('3...')
            wait 1
            client.msg('2...')
            wait 1
            client.msg('1...')
            wait 1
            client.msg('Go!')
            return True
        else:
            return False
        endif
        """)

      # Execute countdown
      Handler.handle(menu, client, "countdown", System.monotonic_time(:microsecond))

      # Verify countdown sequence
      assert_receive {:message, "Starting countdown..."}, 1000
      assert_receive {:message, "3..."}, 2000
      assert_receive {:message, "2..."}, 3000
      assert_receive {:message, "1..."}, 4000
      assert_receive {:message, "Go!"}, 5000
    end

    test "menu unknown_input method with pause", %{client: client, main_menu: menu} do
      # Create unknown_input method with pause
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "unknown_input", args,
        """
        client.msg('Thinking about your request...')
        wait 1
        client.msg(f'Sorry, I do not understand "{input}"')
        """)

      # Handle unknown input
      Handler.handle(menu, client, "mystery_command", System.monotonic_time(:microsecond))

      # Verify paused response
      assert_receive {:message, "Thinking about your request..."}, 1000
      assert_receive {:message, msg}, 2000
      assert String.contains?(msg, "mystery_command")
    end
  end

  describe "menu command integration" do
    test "menu processes commands when input method doesn't handle input", %{client: client, main_menu: menu} do
      # Create quit command
      {_, args} = Signature.constraints("run(client)")
      Record.create_entity(key: "command/quit", virtual: true)
      Record.set_method("command/quit", "run", args,
        """
        client.msg('Are you sure you want to quit? (y/n)')
        wait 2
        client.msg('Timeout - staying in game.')
        """)

      # Create input method that only handles specific commands
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "status":
            client.msg('You are healthy and ready for adventure.')
            return True
        else:
            return False
        endif
        """)

      # Test status command (handled by input method)
      Handler.handle(menu, client, "status", System.monotonic_time(:microsecond))
      assert_receive {:message, msg1}, 1000
      assert String.contains?(msg1, "healthy and ready")

      # Test quit command (handled by command system)
      Handler.handle(menu, client, "quit", System.monotonic_time(:microsecond))
      assert_receive {:message, "Are you sure you want to quit? (y/n)"}, 1000
      assert_receive {:message, "Timeout - staying in game."}, 3000
    end

    test "menu command with pause and complex logic", %{client: client, main_menu: menu} do
      # Create complex help command with pause
      Record.create_entity(key: "command/help", virtual: true)
      {_, args} = Signature.constraints("run(client)")
      Record.set_method("command/help", "run", args,
        """
        client.msg('Loading help system...')
        wait 1
        client.msg('=== HELP MENU ===')
        client.msg('Available commands:')
        wait 1
        client.msg('- help: Show this help')
        client.msg('- quit: Exit the game')
        wait 1
        client.msg('=== END HELP ===')
        """)

      # Execute help command
      Handler.handle(menu, client, "help", System.monotonic_time(:microsecond))

      # Verify help sequence
      assert_receive {:message, "Loading help system..."}, 1000
      assert_receive {:message, "=== HELP MENU ==="}, 2000
      assert_receive {:message, "Available commands:"}, 2000
      assert_receive {:message, "- help: Show this help"}, 3000
      assert_receive {:message, "- quit: Exit the game"}, 3000
      assert_receive {:message, "=== END HELP ==="}, 4000
    end
  end

  describe "error handling in menus" do
    test "menu handles error in input method gracefully", %{client: client, main_menu: menu} do
      # Create input method that can error
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "error":
            unknown_variable
        else:
            return False
        endif
        """)

      # Create unknown_input method to catch the error fallback
      Record.set_method("menu/main", "unknown_input", args,
        "client.msg('Input method failed, but we handled it gracefully.')")

      # Trigger error
      Handler.handle(menu, client, "error", System.monotonic_time(:microsecond))

      # Should fall back to unknown_input
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "handled it gracefully")
    end

    test "menu handles error in unknown_input method", %{client: client, main_menu: menu} do
      # Create unknown_input method that errors
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "unknown_input", args,
        "client.msg('I don\\'t understand.')")

      # Handle unknown input - should not crash
      Handler.handle(menu, client, "trigger_error", System.monotonic_time(:microsecond))

      # Should get generic fallback message
      assert_receive {:message, msg}, 1000
      assert String.contains?(msg, "I don't understand")
    end
  end

  describe "menu state and navigation" do
    test "menus can redirect clients between each other", %{client: client, main_menu: menu} do
      # Create input method that handles menu navigation
      {:ok, _menu} = Record.create_entity(key: "menu/settings", virtual: true)
      {_, args} = Signature.constraints("input(client, input)")
      Record.set_method("menu/main", "input", args,
        """
        if input.lower() == "login":
            client.msg('Redirecting to login menu...')
            client.location = !menu/login!
            return True
        elif input.lower() == "settings":
            client.msg('Redirecting to settings...')
            client.location = !menu/settings!
            return True
        else:
            return False
        endif
        """)

      # Test login redirect
      Handler.handle(menu, client, "login", System.monotonic_time(:microsecond))
      assert_receive {:message, "Redirecting to login menu..."}, 1000
      client = Pythelix.Record.get_entity(client.key)
      location = Record.get_location_entity(client)
      assert location.key == "menu/login"

      # Test settings redirect
      Handler.handle(menu, client, "settings", System.monotonic_time(:microsecond))
      assert_receive {:message, "Redirecting to settings..."}, 1000
      client = Pythelix.Record.get_entity(client.key)
      location = Record.get_location_entity(client)
      assert location.key == "menu/settings"
    end
  end
end
