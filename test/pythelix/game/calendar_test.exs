defmodule Pythelix.Game.CalendarTest do
  use Pythelix.ScriptingCase

  alias Pythelix.Game.Calendar
  alias Pythelix.Record

  # Helper to create a custom calendar with units via worldlet scripting
  defp create_custom_calendar do
    Pythelix.World.apply(:static)

    {:ok, _} = Record.create_entity(key: "test_calendar", parent: Record.get_entity("generic/calendar"))
    Record.set_attribute("test_calendar", "type", "custom")
    Record.set_attribute("test_calendar", "offset", 0)

    # Build units as a map simulating sub-entities
    # second (base), minute (60 seconds), hour (60 minutes), day (24 hours)
    units = %{
      "second" => %{"__name" => "base"},
      "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
      "hour" => %{"__base" => "minute", "__factor" => 60, "__start" => 0},
      "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1}
    }

    Record.set_attribute("test_calendar", "units", units)
    Record.get_entity("test_calendar")
  end

  defp create_calendar_with_offset do
    Pythelix.World.apply(:static)

    {:ok, _} = Record.create_entity(key: "offset_calendar", parent: Record.get_entity("generic/calendar"))
    Record.set_attribute("offset_calendar", "type", "custom")
    Record.set_attribute("offset_calendar", "offset", 0)

    units = %{
      "second" => %{"__name" => "base"},
      "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
      "hour" => %{"__base" => "minute", "__factor" => 60, "__start" => 0},
      "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1},
      "year" => %{"__base" => "day", "__factor" => 365, "__start" => 2300}
    }

    Record.set_attribute("offset_calendar", "units", units)
    Record.get_entity("offset_calendar")
  end

  defp create_gregorian_calendar do
    Pythelix.World.apply(:static)

    {:ok, _} = Record.create_entity(key: "greg_calendar", parent: Record.get_entity("generic/calendar"))
    Record.set_attribute("greg_calendar", "type", "gregorian")
    Record.set_attribute("greg_calendar", "offset", 0)
    Record.get_entity("greg_calendar")
  end

  describe "compute_units/2 with custom calendar" do
    test "computes basic units from seconds" do
      calendar = create_custom_calendar()

      # 3661 seconds = 1 hour, 1 minute, 1 second, day 1
      units = Calendar.compute_units(3661, calendar)
      assert units["second"] == 1
      assert units["minute"] == 1
      assert units["hour"] == 1
      assert units["day"] == 1
    end

    test "computes wrapped values correctly" do
      calendar = create_custom_calendar()

      # 90061 seconds = 25 hours + 1 second = 1 day 1 hour 1 minute 1 second
      # Actually: 90061 = 25*3600 + 1*60 + 1
      # day = div(90061, 86400) + 1 = 1 + 1 = 2
      # hour = rem(div(90061, 3600), 24) = rem(25, 24) = 1
      # minute = rem(div(90061, 60), 60) = rem(1501, 60) = 1
      # second = rem(90061, 60) = 1
      units = Calendar.compute_units(90061, calendar)
      assert units["second"] == 1
      assert units["minute"] == 1
      assert units["hour"] == 1
      assert units["day"] == 2
    end
  end

  describe "compute_units/2 with start offsets" do
    test "year starts at configured offset" do
      calendar = create_calendar_with_offset()

      # 0 seconds = year 2300, day 1, hour 0, minute 0, second 0
      units = Calendar.compute_units(0, calendar)
      assert units["year"] == 2300
      assert units["day"] == 1
      assert units["hour"] == 0
    end

    test "after one year of seconds" do
      calendar = create_calendar_with_offset()

      # 365 days worth of seconds
      one_year = 365 * 24 * 3600
      units = Calendar.compute_units(one_year, calendar)
      assert units["year"] == 2301
      assert units["day"] == 1
    end
  end

  describe "compute_units/2 with gregorian calendar" do
    test "interprets epoch as Unix timestamp" do
      calendar = create_gregorian_calendar()

      # Unix epoch 0 = 1970-01-01 00:00:00
      units = Calendar.compute_units(0, calendar)
      assert units["year"] == 1970
      assert units["month"] == 1
      assert units["day"] == 1
      assert units["hour"] == 0
    end

    test "computes correct date for known timestamp" do
      calendar = create_gregorian_calendar()

      # 2024-01-15 12:30:00 UTC
      {:ok, dt} = DateTime.new(~D[2024-01-15], ~T[12:30:00], "Etc/UTC")
      unix = DateTime.to_unix(dt)

      units = Calendar.compute_units(unix, calendar)
      assert units["year"] == 2024
      assert units["month"] == 1
      assert units["day"] == 15
      assert units["hour"] == 12
      assert units["minute"] == 30
    end
  end

  describe "compute_properties/2" do
    test "computes boundary properties (list format)" do
      _calendar = create_custom_calendar()

      # Properties use a list of sub-entities per key; range is [from, to) inclusive-exclusive
      properties = %{
        "time_of_day" => [
          %{"__unit" => "hour", "__from" => 0, "__to" => 12, "__value" => "morning"},
          %{"__unit" => "hour", "__from" => 12, "__to" => 18, "__value" => "afternoon"},
          %{"__unit" => "hour", "__from" => 18, "__to" => 24, "__value" => "evening"}
        ]
      }

      Record.set_attribute("test_calendar", "properties", properties)
      calendar = Record.get_entity("test_calendar")

      units = %{"hour" => 8, "minute" => 30, "second" => 0, "day" => 1}
      props = Calendar.compute_properties(units, calendar)
      assert props["time_of_day"] == "morning"

      units2 = %{"hour" => 14, "minute" => 0, "second" => 0, "day" => 1}
      props2 = Calendar.compute_properties(units2, calendar)
      assert props2["time_of_day"] == "afternoon"
    end

    test "boundary inclusive-exclusive: upper bound is not included" do
      _calendar = create_custom_calendar()

      properties = %{
        "slot" => [%{"__unit" => "hour", "__from" => 0, "__to" => 12, "__value" => "first half"}]
      }

      Record.set_attribute("test_calendar", "properties", properties)
      calendar = Record.get_entity("test_calendar")

      # hour=11 is in [0, 12) → matches
      props = Calendar.compute_properties(%{"hour" => 11}, calendar)
      assert props["slot"] == "first half"

      # hour=12 is NOT in [0, 12) → no match
      props2 = Calendar.compute_properties(%{"hour" => 12}, calendar)
      assert Map.get(props2, "slot") == nil
    end

    test "no match in list returns nil for that property" do
      _calendar = create_custom_calendar()

      properties = %{
        "time_of_day" => [
          %{"__unit" => "hour", "__from" => 0, "__to" => 12, "__value" => "morning"}
        ]
      }

      Record.set_attribute("test_calendar", "properties", properties)
      calendar = Record.get_entity("test_calendar")

      units = %{"hour" => 14, "minute" => 0, "second" => 0, "day" => 1}
      props = Calendar.compute_properties(units, calendar)
      assert Map.get(props, "time_of_day") == nil
    end

    test "GameTimeDefault matches when no boundary matches (fallback)" do
      _calendar = create_custom_calendar()

      properties = %{
        "time_of_day" => [
          %{"__unit" => "hour", "__from" => 6, "__to" => 22, "__value" => "day"},
          %{"__value" => "night", "__default" => true}
        ]
      }

      Record.set_attribute("test_calendar", "properties", properties)
      calendar = Record.get_entity("test_calendar")

      # hour=3 is outside [6, 22), so the default fires
      props = Calendar.compute_properties(%{"hour" => 3}, calendar)
      assert props["time_of_day"] == "night"

      # hour=12 is inside [6, 22), so the boundary fires first
      props2 = Calendar.compute_properties(%{"hour" => 12}, calendar)
      assert props2["time_of_day"] == "day"
    end

    test "computes index-based properties" do
      _calendar = create_custom_calendar()

      properties = %{
        "day_name" => [
          %{"__unit" => "day", "__index" => 1, "__value" => "first day"},
          %{"__unit" => "day", "__index" => 3, "__value" => "third day"}
        ]
      }

      Record.set_attribute("test_calendar", "properties", properties)
      calendar = Record.get_entity("test_calendar")

      units = %{"hour" => 0, "minute" => 0, "second" => 0, "day" => 3}
      props = Calendar.compute_properties(units, calendar)
      assert props["day_name"] == "third day"
    end
  end

  describe "project_units/3" do
    test "projects with positive adjustment" do
      calendar = create_custom_calendar()

      # Start at 0 seconds, project +2 hours
      {adjusted_epoch, units} = Calendar.project_units(0, calendar, %{"hour" => 2})
      assert units["hour"] == 2
      assert units["minute"] == 0
      assert adjusted_epoch == 2 * 3600
    end

    test "projects with negative adjustment" do
      calendar = create_custom_calendar()

      # Start at 2 hours, project -1 hour
      base_seconds = 2 * 3600
      {_adjusted_epoch, units} = Calendar.project_units(base_seconds, calendar, %{"hour" => -1})
      assert units["hour"] == 1
    end
  end

  describe "cyclic units" do
    defp create_calendar_with_cyclic_unit do
      Pythelix.World.apply(:static)

      {:ok, _} = Record.create_entity(key: "cyclic_calendar", parent: Record.get_entity("generic/calendar"))
      Record.set_attribute("cyclic_calendar", "type", "custom")
      Record.set_attribute("cyclic_calendar", "offset", 0)

      units = %{
        "second" => %{"__name" => "base"},
        "minute" => %{"__base" => "second", "__factor" => 60, "__start" => 0},
        "hour" => %{"__base" => "minute", "__factor" => 60, "__start" => 0},
        "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1},
        "month" => %{"__base" => "day", "__factor" => 30, "__start" => 1},
        "year" => %{"__base" => "month", "__factor" => 12, "__start" => 1},
        "weekday" => %{"__base" => "day", "__cycle" => 7, "__start" => 1, "__offset" => 0, "__cyclic" => true}
      }

      Record.set_attribute("cyclic_calendar", "units", units)
      Record.get_entity("cyclic_calendar")
    end

    test "computes cyclic weekday values cycling 1-7" do
      calendar = create_calendar_with_cyclic_unit()

      # Day 1 (0 seconds into day 1): weekday = rem(0 + 0, 7) + 1 = 1
      units = Calendar.compute_units(0, calendar)
      assert units["weekday"] == 1
      assert units["day"] == 1

      # Day 2 (1 day = 86400 seconds): weekday = rem(1, 7) + 1 = 2
      units = Calendar.compute_units(86400, calendar)
      assert units["weekday"] == 2
      assert units["day"] == 2

      # Day 7 (6 days): weekday = rem(6, 7) + 1 = 7
      units = Calendar.compute_units(6 * 86400, calendar)
      assert units["weekday"] == 7

      # Day 8 (7 days): weekday = rem(7, 7) + 1 = 1 (cycles back)
      units = Calendar.compute_units(7 * 86400, calendar)
      assert units["weekday"] == 1
    end

    test "weekday cycles across month boundaries" do
      calendar = create_calendar_with_cyclic_unit()

      # Day 30 of month 1 (29 days elapsed): weekday = rem(29, 7) + 1 = 2
      units = Calendar.compute_units(29 * 86400, calendar)
      assert units["weekday"] == rem(29, 7) + 1
      assert units["day"] == 30
      assert units["month"] == 1

      # Day 1 of month 2 (30 days elapsed): weekday = rem(30, 7) + 1 = 3
      units = Calendar.compute_units(30 * 86400, calendar)
      assert units["weekday"] == rem(30, 7) + 1
      assert units["day"] == 1
      assert units["month"] == 2
    end

    test "cyclic unit does not interfere with regular units" do
      calendar = create_calendar_with_cyclic_unit()

      # 90061 seconds = same as the regular test
      units = Calendar.compute_units(90061, calendar)
      assert units["second"] == 1
      assert units["minute"] == 1
      assert units["hour"] == 1
      assert units["day"] == 2
      assert units["weekday"] == 2
    end

    test "project by cyclic unit advances by base unit seconds" do
      calendar = create_calendar_with_cyclic_unit()

      # Project by weekday=2 should advance by 2 days (2 * 86400)
      {adjusted_epoch, units} = Calendar.project_units(0, calendar, %{"weekday" => 2})
      assert adjusted_epoch == 2 * 86400
      assert units["day"] == 3
      assert units["weekday"] == 3
    end

    test "cyclic unit with offset shifts the cycle" do
      Pythelix.World.apply(:static)

      {:ok, _} = Record.create_entity(key: "offset_cyclic_cal", parent: Record.get_entity("generic/calendar"))
      Record.set_attribute("offset_cyclic_cal", "type", "custom")
      Record.set_attribute("offset_cyclic_cal", "offset", 0)

      units = %{
        "second" => %{"__name" => "base"},
        "hour" => %{"__base" => "second", "__factor" => 3600, "__start" => 0},
        "day" => %{"__base" => "hour", "__factor" => 24, "__start" => 1},
        "weekday" => %{"__base" => "day", "__cycle" => 7, "__start" => 1, "__offset" => 3, "__cyclic" => true}
      }

      Record.set_attribute("offset_cyclic_cal", "units", units)
      calendar = Record.get_entity("offset_cyclic_cal")

      # Day 0 elapsed: weekday = rem(0 + 3, 7) + 1 = 4
      units = Calendar.compute_units(0, calendar)
      assert units["weekday"] == 4
    end
  end

  describe "gregorian weekday" do
    test "returns weekday 1 (Monday) through 7 (Sunday)" do
      calendar = create_gregorian_calendar()

      # 2024-01-15 is a Monday (weekday 1)
      {:ok, dt} = DateTime.new(~D[2024-01-15], ~T[12:00:00], "Etc/UTC")
      unix = DateTime.to_unix(dt)
      units = Calendar.compute_units(unix, calendar)
      assert units["weekday"] == 1

      # 2024-01-21 is a Sunday (weekday 7)
      {:ok, dt} = DateTime.new(~D[2024-01-21], ~T[12:00:00], "Etc/UTC")
      unix = DateTime.to_unix(dt)
      units = Calendar.compute_units(unix, calendar)
      assert units["weekday"] == 7
    end

    test "project by weekday advances by days" do
      calendar = create_gregorian_calendar()

      {:ok, dt} = DateTime.new(~D[2024-01-15], ~T[12:00:00], "Etc/UTC")
      unix = DateTime.to_unix(dt)

      {_adjusted, units} = Calendar.project_units(unix, calendar, %{"weekday" => 2})
      # 2 days after Monday Jan 15 = Wednesday Jan 17
      assert units["day"] == 17
      assert units["weekday"] == 3
    end
  end
end
