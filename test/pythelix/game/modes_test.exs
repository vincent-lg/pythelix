defmodule Pythelix.Game.ModesTest do
  @moduledoc """
  Module to test the game mode structure itself.
  """

  use ExUnit.Case, async: true

  alias Pythelix.Game.Modes

  defp modes(keys, active) do
    %Modes{active: active, game_modes: Enum.map(keys, &{&1, nil})}
  end

  defp keys(%Modes{game_modes: game_modes}) do
    Enum.map(game_modes, fn {menu, _owner} -> menu end)
  end

  defp menu(key) do
    %Pythelix.Entity{id: nil, key: key, location_id: nil}
  end

  describe "aiming and moving" do
    test "a plain input is handled where the character stands" do
      stack = modes(["menu/editor", "menu/game"], 1)

      aimed = Modes.aim(stack)
      assert aimed.target == nil
      assert Modes.target(aimed) == 1
    end

    test "aiming leaves the character where it stands" do
      stack = modes(["menu/editor", "menu/console", "menu/game"], 0)

      aimed = Modes.aim(stack, 1)
      assert aimed.active == 0
      assert Modes.target(aimed) == 1
    end

    test "aiming is counted from where the character stands, not from the last aim" do
      stack = modes(["menu/editor", "menu/console", "menu/game"], 0)

      assert stack |> Modes.aim(1) |> Modes.aim(1) |> Modes.target() == 1
    end

    test "aiming wraps around the stack" do
      stack = modes(["menu/editor", "menu/game"], 0)

      assert stack |> Modes.aim(-1) |> Modes.target() == 1
      assert stack |> Modes.aim(3) |> Modes.target() == 1
    end

    test "moving takes the character along and forgets the aim" do
      stack = modes(["menu/editor", "menu/console", "menu/game"], 0)

      moved = stack |> Modes.aim(2) |> Modes.move(1)
      assert moved.active == 1
      assert moved.target == nil
    end

    test "moving backwards wraps around the stack" do
      stack = modes(["menu/editor", "menu/game"], 0)

      assert Modes.move(stack, -1).active == 1
    end
  end

  describe "add" do
    test "an added mode becomes the one the character stands on" do
      stack = modes(["menu/game"], 0)
      menu = menu("menu/editor")

      added = Modes.add(stack, menu, nil, active: true)
      assert keys(added) == ["menu/editor", "menu/game"]
      assert added.active == 0
      assert added.target == nil
    end

    test "adding a mode in the background leaves the character on its own menu" do
      stack = modes(["menu/console", "menu/game"], 1)
      menu = menu("menu/editor")

      added = Modes.add(stack, menu, nil)
      assert keys(added) == ["menu/editor", "menu/console", "menu/game"]
      # Still the game menu, which slid from index 1 to index 2.
      assert added.active == 2
    end
  end

  describe "close" do
    test "closing the top mode brings back the one below it" do
      stack = modes(["menu/editor", "menu/game"], 0)

      assert {:ok, closed} = Modes.close(stack)
      assert keys(closed) == ["menu/game"]
      assert closed.active == 0
    end

    test "closing a mode the character has moved away from leaves the others alone" do
      stack = modes(["menu/editor", "menu/console", "menu/game"], 1)

      assert {:ok, closed} = Modes.close(stack)
      assert keys(closed) == ["menu/editor", "menu/game"]
      # The game menu, which was below the console, is now the active one.
      assert closed.active == 1
    end

    test "closing the deepest mode falls back on the new deepest one" do
      stack = modes(["menu/editor", "menu/game"], 1)

      assert {:ok, closed} = Modes.close(stack)
      assert keys(closed) == ["menu/editor"]
      assert closed.active == 0
    end

    test "closing the same menu twice closes one instance at a time" do
      stack = modes(["menu/editor", "menu/editor", "menu/game"], 0)

      assert {:ok, closed} = Modes.close(stack)
      assert keys(closed) == ["menu/editor", "menu/game"]

      assert {:ok, closed} = Modes.close(closed)
      assert keys(closed) == ["menu/game"]
    end

    test "the owner of the closed mode does not matter" do
      stack = %Modes{
        active: 0,
        game_modes: [{"menu/game", "npc/guard"}, {"menu/game", nil}]
      }

      assert {:ok, closed} = Modes.close(stack)
      assert closed.game_modes == [{"menu/game", nil}]
    end

    test "the last mode cannot be closed" do
      assert Modes.close(%Modes{}) == :error
    end

    test "an out-of-range active index still closes something" do
      stack = modes(["menu/editor", "menu/game"], 7)

      assert {:ok, closed} = Modes.close(stack)
      assert keys(closed) == ["menu/editor"]
      assert closed.active == 0
    end
  end
end
