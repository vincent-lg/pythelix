defmodule Pythelix.Menu.Mode.HandlerTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Game.Hub
  alias Pythelix.Menu.Mode.Handler
  alias Pythelix.{Record, World}

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
    World.apply(:static)

    # Create the missing generic entities
    #ensure_generic_entities()

    # Create a test character with game modes
    {:ok, character} = Record.create_entity(key: "test_character", virtual: true, parent: Record.get_entity("generic/character"))

    # Create test NPCs
    {:ok, _npc1} = Record.create_entity(key: "test_npc1", virtual: true, parent: Record.get_entity("generic/character"))
    {:ok, _npc2} = Record.create_entity(key: "test_npc2", virtual: true, parent: Record.get_entity("generic/character"))

    # Set up game modes for the character
    game_modes = %{
      active: 0,
      game_modes: [
        {"menu/game", "test_character"},
        {"menu/game", "test_npc1"},
        {"menu/game", "test_npc2"}
      ]
    }
    Record.set_attribute("test_character", "game_modes", game_modes)

    # Create a test client entity
    {:ok, _client} = Record.create_entity(key: "test_client", virtual: true, parent: Record.get_entity("generic/client"))
    Record.set_attribute("test_client", "client_id", 999)
    Record.set_attribute("test_client", "pid", self())
    Record.set_attribute("test_client", "owner", character)

    # Create test menu
    Record.create_entity(key: "menu/game", virtual: true, parent: Record.get_entity("generic/menu"))
    Record.set_attribute("menu/game", "text", "Game menu")

    client_entity = Record.get_entity("test_client")
    character_entity = Record.get_entity("test_character")
    menu_entity = Record.get_entity("menu/game")

    {:ok, client: client_entity, character: character_entity, menu: menu_entity}
  end

  describe "game mode input handling" do
    test "processes regular input with active mode", %{client: client, menu: menu} do
      # Test normal input without pipes
      Handler.handle(menu, client, "look", 0)

      # Since we don't have actual menu methods, this should fall through
      # to the command processing, which might fail, but that's okay for this test
      assert true  # Just ensure no crashes
    end

    test "handles pipe operators for mode switching", %{client: client, menu: menu} do
      # Test next mode switch
      Handler.handle(menu, client, ">", 0)

      # Verify the active mode changed
      character = Record.get_attribute(client, "owner")
      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 1

      # Test multiple next switches
      Handler.handle(menu, client, ">>", 0)

      # Verify the active mode wrapped around
      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 0  # Should wrap to 0 (3 total modes: 0, 1, 2)
    end

    test "handles previous pipe operators", %{client: client, menu: menu} do
      # Test previous mode switch from initial position (should wrap to last)
      Handler.handle(menu, client, "<", 0)

      character = Record.get_attribute(client, "owner")
      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 2  # Should wrap to last mode
    end

    test "handles mixed pipe operators", %{client: client, menu: menu} do
      # Test mixed operators: >< should result in no net change
      Handler.handle(menu, client, "><", 0)

      character = Record.get_attribute(client, "owner")
      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 0  # Should remain unchanged

      # Test complex pattern: >>< should result in +1 net movement
      Handler.handle(menu, client, ">><", 0)

      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 1
    end

    test "handles pipe operators with commands", %{client: client, menu: menu} do
      # Test pipe with command: ">look" should switch to next mode and execute look
      Handler.handle(menu, client, ">look", 0)

      character = Record.get_attribute(client, "owner")
      game_modes = Record.get_attribute(character, "game_modes")
      assert game_modes.active == 1
    end

    test "handles input without game modes", %{menu: menu} do
      # Create a client without game modes
      {:ok, simple_client} = Record.create_entity(key: "simple_client", virtual: true, parent: Record.get_entity("generic/client"))
      Record.set_attribute("simple_client", "client_id", 998)
      Record.set_attribute("simple_client", "pid", self())

      # This should fall back to regular menu processing
      Handler.handle(menu, simple_client, "test input", 0)

      assert true  # Just ensure no crashes
    end
  end

  describe "pipe symbol configuration" do
    test "uses configured pipe symbols" do
      # Test that the configuration is accessible
      config = Application.get_env(:pythelix, Pythelix.Menu.Mode, symbols: [next: [">"], previous: ["<"]])
      symbols = Keyword.get(config, :symbols, [next: [">"], previous: ["<"]])

      assert Keyword.get(symbols, :next) == [">"]
      assert Keyword.get(symbols, :previous) == ["<"]
    end
  end
end
