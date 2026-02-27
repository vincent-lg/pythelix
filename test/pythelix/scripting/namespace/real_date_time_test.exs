defmodule Pythelix.Scripting.Namespace.RealDateTimeTest do
  use Pythelix.ScriptingCase

  describe "attributes" do
    test "year, month, day, hour, minute, second are accessible" do
      script = run("""
      dt = realtime.now()
      y = dt.year
      mo = dt.month
      d = dt.day
      h = dt.hour
      mi = dt.minute
      s = dt.second
      """)

      assert is_integer(Script.get_variable_value(script, "y"))
      assert is_integer(Script.get_variable_value(script, "mo"))
      assert is_integer(Script.get_variable_value(script, "d"))
      assert is_integer(Script.get_variable_value(script, "h"))
      assert is_integer(Script.get_variable_value(script, "mi"))
      assert is_integer(Script.get_variable_value(script, "s"))
    end

    test "weekday returns 1 (Monday) through 7 (Sunday)" do
      value = expr_ok("realtime.now().weekday")
      assert is_integer(value)
      assert value >= 1 and value <= 7
    end

    test "weekday changes when advancing by a day" do
      script = run("""
      dt = realtime.now()
      tomorrow = dt.add(86400)
      diff = tomorrow.weekday - dt.weekday
      """)

      diff = Script.get_variable_value(script, "diff")
      # Should be +1 or -6 (when wrapping from Sunday to Monday)
      assert diff == 1 or diff == -6
    end

    test "timezone returns offset string" do
      script = run("""
      dt = realtime.now()
      tz = dt.timezone
      """)

      tz = Script.get_variable_value(script, "tz")
      assert is_binary(tz)
      assert String.contains?(tz, ":") or tz == "Z"
    end
  end

  describe "add()" do
    test "advances by integer seconds" do
      script = run("""
      dt = realtime.now()
      future = dt.add(3600)
      diff = future.hour - dt.hour
      """)

      diff = Script.get_variable_value(script, "diff")
      assert diff == 1 or diff == -23
    end

    test "returns a new RealDateTime, original unchanged" do
      script = run("""
      dt = realtime.now()
      h_before = dt.hour
      future = dt.add(3600)
      h_after = dt.hour
      """)

      assert Script.get_variable_value(script, "h_before") ==
             Script.get_variable_value(script, "h_after")
    end
  end

  describe "sub()" do
    test "goes back by integer seconds" do
      script = run("""
      dt = realtime.now()
      past = dt.sub(3600)
      diff = dt.hour - past.hour
      """)

      diff = Script.get_variable_value(script, "diff")
      assert diff == 1 or diff == -23
    end
  end

  describe "str() and repr()" do
    test "str returns datetime as string" do
      script = run("""
      dt = realtime.now()
      result = str(dt)
      """)

      result = Script.get_variable_value(script, "result")
      assert is_binary(result)
    end

    test "repr returns formatted representation" do
      script = run("""
      dt = realtime.now()
      result = repr(dt)
      """)

      result = Script.get_variable_value(script, "result")
      assert String.starts_with?(result, "<RealDateTime ")
    end

    test "no timezone repetition in repr" do
      script = run("""
      result = repr(realtime.now())
      """)

      result = Script.get_variable_value(script, "result")
      # Should look like "<RealDateTime 2026-02-26 19:15:04+01:00>"
      # The offset should appear only once
      offset_count =
        Regex.scan(~r/[+-]\d{2}:\d{2}|Z/, result)
        |> length()

      assert offset_count == 1
    end
  end
end
