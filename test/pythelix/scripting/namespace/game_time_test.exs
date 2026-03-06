defmodule Pythelix.Scripting.Namespace.GameTimeTest do
  use Pythelix.ScriptingCase

  alias Pythelix.Game.Epoch
  alias Pythelix.Record

  setup do
    Pythelix.World.apply(:static)

    {:ok, _} = Record.create_entity(key: "game_epoch")
    Record.set_attribute("game_epoch", "scale", 10)
    Record.set_attribute("game_epoch", "started_at", System.system_time(:second) - 100)
    Epoch.init()

    {:ok, _} =
      Record.create_entity(key: "gt_ns_calendar", parent: Record.get_entity("generic/calendar"))

    Record.set_attribute("gt_ns_calendar", "type", "custom")
    Record.set_attribute("gt_ns_calendar", "offset", 0)

    units = %{
      "second" => %{"__name" => "base"},
      "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
      "hour" => %{"__base" => "minute", "__factor" => 60, "__start" => 0},
      "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1}
    }

    Record.set_attribute("gt_ns_calendar", "units", units)
    Epoch.cache_calendars()

    :ok
  end

  describe "GameTime attributes" do
    test "unit values are accessible as attributes" do
      script =
        run("""
        gt = gametime.now(!gt_ns_calendar!)
        h = gt.hour
        d = gt.day
        """)

      assert is_integer(Script.get_variable_value(script, "h"))
      assert Script.get_variable_value(script, "d") >= 1
    end

    test "property values are accessible as attributes" do
      properties = %{
        "time_of_day" => [
          %{"__unit" => "hour", "__from" => 0, "__to" => 24, "__value" => "daytime"}
        ]
      }

      Record.set_attribute("gt_ns_calendar", "properties", properties)

      script =
        run("""
        gt = gametime.now(!gt_ns_calendar!)
        tod = gt.time_of_day
        """)

      assert Script.get_variable_value(script, "tod") == "daytime"
    end
  end

  describe "str() and repr()" do
    test "str returns unit values as string" do
      script =
        run("""
        gt = gametime.now(!gt_ns_calendar!)
        result = str(gt)
        """)

      result = Script.get_variable_value(script, "result")
      assert is_binary(result)
      assert String.contains?(result, "hour=")
    end

    test "repr returns formatted representation" do
      script =
        run("""
        gt = gametime.now(!gt_ns_calendar!)
        result = repr(gt)
        """)

      result = Script.get_variable_value(script, "result")
      assert String.starts_with?(result, "<GameTime ")
    end
  end
end
