defmodule Pythelix.Scripting.Namespace.DurationTest do
  @moduledoc """
  Module to test the duration namespace API.
  """

  use Pythelix.ScriptingCase

  describe "attributes" do
    test "seconds" do
      value = expr_ok("30s.seconds")
      assert value == 30
    end

    test "minutes" do
      value = expr_ok("5m.minutes")
      assert value == 5
    end

    test "hours" do
      value = expr_ok("2h.hours")
      assert value == 2
    end

    test "days" do
      value = expr_ok("3d.days")
      assert value == 3
    end

    test "months" do
      value = expr_ok("6o.months")
      assert value == 6
    end

    test "years" do
      value = expr_ok("1y.years")
      assert value == 1
    end
  end

  describe "__repr__" do
    test "format seconds" do
      value = expr_ok("str(30s)")
      assert value == "30s"
    end

    test "format combined" do
      value = expr_ok("str(2h30m)")
      assert value == "2h30m"
    end

    test "format complex" do
      value = expr_ok("str(1h15m30s)")
      assert value == "1h15m30s"
    end
  end

  describe "total_seconds" do
    test "from seconds" do
      value = expr_ok("30s.total_seconds()")
      assert value == 30
    end

    test "from minutes" do
      value = expr_ok("3m.total_seconds()")
      assert value == 180
    end

    test "from hours" do
      value = expr_ok("2h.total_seconds()")
      assert value == 7200
    end

    test "from combined" do
      value = expr_ok("1h30m.total_seconds()")
      assert value == 5400
    end

    test "from days" do
      value = expr_ok("1d.total_seconds()")
      assert value == 86400
    end
  end

  describe "wait" do
    test "wait with a duration converts to seconds" do
      script = Pythelix.Scripting.run("wait 2m30s")
      assert script.pause == 150
    end

    test "wait with a simple duration" do
      script = Pythelix.Scripting.run("wait 5s")
      assert script.pause == 5
    end
  end
end
