defmodule Pythelix.Scripting.Namespace.GameModesTest do
  @moduledoc """
  Module to test the game mode scripting namespace.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Game.{Hub, Modes}
  alias Pythelix.{Record, World}

  setup_all do
    # Start the Game Hub for new system
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    World.apply(:static)
    :ok
  end

  describe "check" do
    test "the character game modes should always contain one entry" do
      modes =
        expr_ok("""
        char = !generic/character!
        char.game_modes
        """)

      assert match?(%Modes{}, modes)
      assert length(modes.game_modes) == 1
    end

    test "the character game modes should point to the menu/game menu" do
      character = Record.get_entity("generic/character")

      modes =
        expr_ok("""
        char = !generic/character!
        char.game_modes
        """)

      {menu, owned} = Modes.get_active(modes, character)
      assert menu.key == "menu/game"
      assert owned == character
    end
  end

  describe "close" do
    test "closing the mode just added brings the game menu back" do
      modes =
        expr_ok("""
        char = !generic/character!
        char.game_modes.add(!menu/motd!)
        char.game_modes.close()
        char.game_modes
        """)

      assert modes.game_modes == [{"menu/game", nil}]
      assert modes.active == 0
    end

    test "closing one of two screens of the same menu leaves the other open" do
      modes =
        expr_ok("""
        char = !generic/character!
        char.game_modes.add(!menu/motd!)
        char.game_modes.add(!menu/motd!)
        char.game_modes.close()
        char.game_modes
        """)

      assert modes.game_modes == [{"menu/motd", nil}, {"menu/game", nil}]
    end

    test "the last mode cannot be closed" do
      traceback =
        expr_fail("""
        char = !generic/character!
        char.game_modes.close()
        """)

      assert traceback.exception == ValueError
    end
  end
end
