defmodule Pythelix.Game.EpochTest do
  use Pythelix.DataCase

  alias Pythelix.Game.Epoch
  alias Pythelix.Record

  describe "Epoch.init/0" do
    test "returns :inactive when no game_epoch entity exists" do
      assert Epoch.init() == :inactive
      assert Epoch.active?() == false
    end

    test "initializes from game_epoch entity with scale" do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 10)

      assert Epoch.init() == :ok
      assert Epoch.active?() == true
      assert Epoch.get_scale() == 10
    end

    test "sets started_at if not already set" do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 1)

      Epoch.init()
      started_at = Epoch.get_started_at()
      assert is_integer(started_at)
      assert started_at > 0
    end
  end

  describe "Epoch.get_clock/0" do
    test "returns 0 when not active" do
      Epoch.init()
      assert Epoch.get_clock() == 0
    end

    test "returns scaled game seconds" do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 10)
      Record.set_attribute("game_epoch", "started_at", System.system_time(:second) - 5)

      Epoch.init()
      clock = Epoch.get_clock()
      # 5 real seconds * scale 10 = ~50 game seconds
      assert clock >= 49 and clock <= 51
    end
  end

  describe "Epoch.reset/0" do
    test "resets clock to approximately 0" do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 10)
      Record.set_attribute("game_epoch", "started_at", System.system_time(:second) - 100)

      Epoch.init()
      assert Epoch.get_clock() > 0

      Epoch.reset()
      clock = Epoch.get_clock()
      assert clock >= 0 and clock <= 1
    end
  end

  describe "Epoch.real_seconds_until/1" do
    test "computes real seconds to reach target game seconds" do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 10)

      Epoch.init()
      Epoch.reset()

      current = Epoch.get_clock()
      target = current + 100
      real_seconds = Epoch.real_seconds_until(target)
      # 100 game seconds / scale 10 = 10 real seconds
      assert_in_delta real_seconds, 10.0, 1.0
    end
  end
end
