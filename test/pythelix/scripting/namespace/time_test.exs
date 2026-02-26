defmodule Pythelix.Scripting.Namespace.TimeTest do
  @moduledoc """
  Module to test the time namespace API.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.{Duration, Time}

  describe "attributes" do
    test "hour" do
      value = expr_ok("15:00.hour")
      assert value == 15
    end

    test "minute" do
      value = expr_ok("15:30.minute")
      assert value == 30
    end

    test "second" do
      value = expr_ok("8:30:45.second")
      assert value == 45
    end

    test "second defaults to 0" do
      value = expr_ok("15:00.second")
      assert value == 0
    end
  end

  describe "__repr__" do
    test "format without seconds" do
      value = expr_ok("str(15:00)")
      assert value == "15:00"
    end

    test "format with seconds" do
      value = expr_ok("str(8:30:45)")
      assert value == "08:30:45"
    end

    test "format with padding" do
      value = expr_ok("str(9:05)")
      assert value == "09:05"
    end
  end

  describe "add" do
    test "add seconds" do
      value = expr_ok("15:00.add(90)")
      assert value == %Time{hour: 15, minute: 1, second: 30}
    end

    test "add a duration" do
      value = expr_ok("15:00.add(2h30m)")
      assert value == %Time{hour: 17, minute: 30, second: 0}
    end

    test "add wraps past midnight" do
      value = expr_ok("23:30.add(3600)")
      assert value == %Time{hour: 0, minute: 30, second: 0}
    end
  end

  describe "difference" do
    test "positive difference" do
      value = expr_ok("15:00.difference(12:00)")
      assert value == %Duration{hours: 3, minutes: 0, seconds: 0}
    end

    test "reversed difference is still positive" do
      value = expr_ok("12:00.difference(15:00)")
      assert value == %Duration{hours: 3, minutes: 0, seconds: 0}
    end

    test "difference with seconds" do
      value = expr_ok("12:30:15.difference(12:00:00)")
      assert value == %Duration{hours: 0, minutes: 30, seconds: 15}
    end
  end
end
