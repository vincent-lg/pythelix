defmodule Pythelix.Scripting.Namespace.Module.GametimeTest do
  use Pythelix.ScriptingCase

  alias Pythelix.Game.Epoch
  alias Pythelix.Record

  setup do
    # Apply base entities (includes generic/calendar)
    Pythelix.World.apply(:static)

    # Create game_epoch entity
    {:ok, _} = Record.create_entity(key: "game_epoch")
    Record.set_attribute("game_epoch", "scale", 10)
    Record.set_attribute("game_epoch", "started_at", System.system_time(:second) - 100)
    Epoch.init()

    # Create a test calendar with basic units
    {:ok, _} =
      Record.create_entity(key: "test_gt_calendar", parent: Record.get_entity("generic/calendar"))

    Record.set_attribute("test_gt_calendar", "type", "custom")
    Record.set_attribute("test_gt_calendar", "offset", 0)

    units = %{
      "second" => %{"__name" => "base"},
      "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
      "hour" => %{"__base" => "minute", "__factor" => 60, "__start" => 0},
      "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1}
    }

    Record.set_attribute("test_gt_calendar", "units", units)

    # Re-cache calendars after creating the new one
    Epoch.cache_calendars()

    :ok
  end

  describe "gametime.clock" do
    test "returns an integer" do
      value = expr_ok("gametime.clock")
      assert is_integer(value)
    end

    test "returns scaled game seconds" do
      value = expr_ok("gametime.clock")
      # 100 real seconds * scale 10 = ~1000 game seconds
      assert value >= 990
    end
  end

  describe "gametime.now() with sub-entity units (worldlet style)" do
    test "works when units are actual GameTimeUnit instances" do
      # Simulate what a worldlet does: create units using sub-entity constructors.
      # This exercises the %Pythelix.SubEntity{} path in Calendar.get_sub_entity_attr.
      run("""
      cal = Entity(key="se_calendar", parent=!generic/calendar!)
      cal.type = "custom"
      cal.offset = 0
      cal.units = {
          "second": GameTimeBaseUnit(),
          "minute": GameTimeUnit("second", 60),
          "hour": GameTimeUnit("minute", 60),
          "day": GameTimeUnit("hour", 24, start=1)
      }
      """)

      Epoch.cache_calendars()

      value = expr_ok("gametime.now(!se_calendar!).hour")
      assert is_integer(value)
    end

    test "project() works with sub-entity units" do
      run("""
      cal = Entity(key="se_calendar2", parent=!generic/calendar!)
      cal.type = "custom"
      cal.offset = 0
      cal.units = {
          "second": GameTimeBaseUnit(),
          "minute": GameTimeUnit("second", 60),
          "hour": GameTimeUnit("minute", 60),
          "day": GameTimeUnit("hour", 24, start=1)
      }
      """)

      Epoch.cache_calendars()

      script =
        run("""
        now = gametime.now(!se_calendar2!)
        future = now.project(hour=2)
        diff = future.hour - now.hour
        """)

      diff = Script.get_variable_value(script, "diff")
      assert diff == 2 or (diff < 0 and diff + 24 == 2)
    end
  end

  describe "gametime.now()" do
    test "returns a GameTime with the sole calendar" do
      value = expr_ok("gametime.now()")
      assert %Pythelix.Scripting.Object.GameTime{} = value
    end

    test "returns a GameTime with explicit calendar" do
      value = expr_ok("gametime.now(!test_gt_calendar!)")
      assert %Pythelix.Scripting.Object.GameTime{} = value
    end

    test "GameTime has hour attribute" do
      value = expr_ok("gametime.now(!test_gt_calendar!).hour")
      assert is_integer(value)
    end

    test "GameTime has day attribute" do
      value = expr_ok("gametime.now(!test_gt_calendar!).day")
      assert is_integer(value)
      assert value >= 1
    end
  end

  describe "gt.project()" do
    test "projects with hour adjustment" do
      script =
        run("""
        now = gametime.now(!test_gt_calendar!)
        future = now.project(hour=2)
        diff = future.hour - now.hour
        """)

      diff = Script.get_variable_value(script, "diff")
      # Projected 2 hours ahead
      assert diff == 2 or (diff < 0 and diff + 24 == 2)
    end
  end

  describe "gametime.reset_to_zero()" do
    test "resets the clock" do
      # Clock should be non-zero before reset
      before = expr_ok("gametime.clock")
      assert before > 0

      expr_ok("gametime.reset_to_zero()")

      after_reset = expr_ok("gametime.clock")
      assert after_reset >= 0 and after_reset <= 1
    end
  end

  describe "cyclic units (worldlet style)" do
    test "GameTimeCyclicUnit weekday returns 1-7" do
      run("""
      cal = Entity(key="cyclic_cal", parent=!generic/calendar!)
      cal.type = "custom"
      cal.offset = 0
      cal.units = {
          "second": GameTimeBaseUnit(),
          "minute": GameTimeUnit("second", 60),
          "hour": GameTimeUnit("minute", 60),
          "day": GameTimeUnit("hour", 24, start=1),
          "month": GameTimeUnit("day", 30, start=1),
          "year": GameTimeUnit("month", 12, start=1),
          "weekday": GameTimeCyclicUnit("day", 7, start=1)
      }
      """)

      Epoch.cache_calendars()

      value = expr_ok("gametime.now(!cyclic_cal!).weekday")
      assert is_integer(value)
      assert value >= 1 and value <= 7
    end

    test "project by cyclic unit advances by base seconds" do
      run("""
      cal = Entity(key="cyclic_cal2", parent=!generic/calendar!)
      cal.type = "custom"
      cal.offset = 0
      cal.units = {
          "second": GameTimeBaseUnit(),
          "minute": GameTimeUnit("second", 60),
          "hour": GameTimeUnit("minute", 60),
          "day": GameTimeUnit("hour", 24, start=1),
          "weekday": GameTimeCyclicUnit("day", 7, start=1)
      }
      """)

      Epoch.cache_calendars()

      script =
        run("""
        now = gametime.now(!cyclic_cal2!)
        future = now.project(weekday=2)
        diff = future.day - now.day
        """)

      diff = Script.get_variable_value(script, "diff")
      assert diff == 2 or (diff < 0 and diff + 24 == 2)
    end

    test "GameTimeProperty works with cyclic unit" do
      run("""
      cal = Entity(key="cyclic_cal3", parent=!generic/calendar!)
      cal.type = "custom"
      cal.offset = 0
      cal.units = {
          "second": GameTimeBaseUnit(),
          "minute": GameTimeUnit("second", 60),
          "hour": GameTimeUnit("minute", 60),
          "day": GameTimeUnit("hour", 24, start=1),
          "weekday": GameTimeCyclicUnit("day", 7, start=1)
      }
      cal.properties = {
          "day_name": [
              GameTimeProperty("weekday", 1, "Monday"),
              GameTimeProperty("weekday", 2, "Tuesday"),
              GameTimeProperty("weekday", 3, "Wednesday"),
              GameTimeProperty("weekday", 4, "Thursday"),
              GameTimeProperty("weekday", 5, "Friday"),
              GameTimeProperty("weekday", 6, "Saturday"),
              GameTimeProperty("weekday", 7, "Sunday")
          ]
      }
      """)

      Epoch.cache_calendars()

      value = expr_ok("gametime.now(!cyclic_cal3!).day_name")

      assert value in [
               "Monday",
               "Tuesday",
               "Wednesday",
               "Thursday",
               "Friday",
               "Saturday",
               "Sunday"
             ]
    end
  end

  describe "error handling" do
    test "error when no calendar and multiple exist" do
      # Create a second calendar
      {:ok, _} =
        Record.create_entity(
          key: "test_gt_calendar2",
          parent: Record.get_entity("generic/calendar")
        )

      Record.set_attribute("test_gt_calendar2", "type", "custom")
      Epoch.cache_calendars()

      expr_fail("gametime.now()")
    end
  end
end
