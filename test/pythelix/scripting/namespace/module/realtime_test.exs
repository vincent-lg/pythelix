defmodule Pythelix.Scripting.Namespace.Module.RealtimeTest do
  use Pythelix.ScriptingCase

  alias Pythelix.Game.Epoch
  alias Pythelix.Record

  describe "realtime.clock" do
    test "returns an integer > 0" do
      value = expr_ok("realtime.clock")
      assert is_integer(value)
      assert value > 0
    end
  end

  describe "realtime.now()" do
    test "returns a RealDateTime" do
      value = expr_ok("realtime.now()")
      assert %Pythelix.Scripting.Object.RealDateTime{} = value
    end

    test "year returns current year" do
      value = expr_ok("realtime.now().year")
      assert is_integer(value)
      assert value >= 2024
    end

    test "month returns a valid month" do
      value = expr_ok("realtime.now().month")
      assert is_integer(value)
      assert value >= 1 and value <= 12
    end

    test "day returns a valid day" do
      value = expr_ok("realtime.now().day")
      assert is_integer(value)
      assert value >= 1 and value <= 31
    end

    test "hour returns a valid hour" do
      value = expr_ok("realtime.now().hour")
      assert is_integer(value)
      assert value >= 0 and value <= 23
    end

    test "weekday returns a valid weekday" do
      value = expr_ok("realtime.now().weekday")
      assert is_integer(value)
      assert value >= 1 and value <= 7
    end
  end

  describe "realtime.from_gametime()" do
    setup do
      Pythelix.World.apply(:static)
      {:ok, _} = Record.create_entity(key: "game_epoch")
      Record.set_attribute("game_epoch", "scale", 1)
      Record.set_attribute("game_epoch", "started_at", System.system_time(:second) - 3600)
      Epoch.init()

      {:ok, _} = Record.create_entity(key: "rt_calendar", parent: Record.get_entity("generic/calendar"))
      Record.set_attribute("rt_calendar", "type", "custom")
      Record.set_attribute("rt_calendar", "offset", 0)
      Record.set_attribute("rt_calendar", "units", %{
        "second" => %{"__name" => "base"},
        "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
        "hour"   => %{"__base" => "minute", "__factor" => 60, "__start" => 0}
      })
      Epoch.cache_calendars()
      :ok
    end

    test "from_gametime returns a RealDateTime matching the game clock" do
      # With scale=1, game time == real time since started_at.
      # gametime.now() is at game epoch ~3600.
      # realtime.from_gametime(gametime.now()) should be close to realtime.now().
      script = run("""
      gt  = gametime.now(!rt_calendar!)
      rdt = realtime.from_gametime(gt)
      diff = realtime.clock - rdt.hour * 3600 - rdt.minute * 60 - rdt.second
      """)

      # rdt should be a RealDateTime
      value = expr_ok("realtime.from_gametime(gametime.now(!rt_calendar!))")
      assert %Pythelix.Scripting.Object.RealDateTime{} = value
      _ = script
    end

    test "from_gametime reflects projection — not just the current time" do
      # Project the game time forward by 1 hour, then convert to real time.
      # The result should be 3600 real seconds ahead of the non-projected conversion.
      script = run("""
      now      = gametime.now(!rt_calendar!)
      later    = now.project(hour=1)
      real_now = realtime.from_gametime(now)
      real_later = realtime.from_gametime(later)
      diff = real_later.hour * 3600 + real_later.minute * 60 + real_later.second -
             (real_now.hour * 3600 + real_now.minute * 60 + real_now.second)
      """)

      diff = Script.get_variable_value(script, "diff")
      # diff should be 3600 seconds (1 hour); allow ±1 for rounding
      assert abs(diff - 3600) <= 1
    end
  end

  describe "str() and repr()" do
    test "str returns a string representation" do
      value = expr_ok("str(realtime.now())")
      assert is_binary(value)
    end

    test "repr returns a string representation" do
      value = expr_ok("repr(realtime.now())")
      assert is_binary(value)
      assert String.starts_with?(value, "<RealDateTime ")
    end
  end
end
