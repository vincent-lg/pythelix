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
      modes = expr_ok(
        """
        char = !generic/character!
        char.game_modes
        """
      )
      assert match?(%Modes{}, modes)
      assert length(modes.game_modes) == 1
    end

    test "the character game modes should point to the menu/game menu" do
      character = Record.get_entity("generic/character")
      modes = expr_ok(
        """
        char = !generic/character!
        char.game_modes
        """
      )
      {menu, owned} = Modes.get_active(modes, character)
      assert menu.key == "menu/game"
      assert owned == character
    end
  end
end
