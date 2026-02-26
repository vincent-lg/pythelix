defmodule Pythelix.Scripting.Parser.DurationTest do
  @moduledoc """
  Module to test that duration literals are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "seconds only" do
    ast = eval_ok("15s")
    assert ast == {:duration, %{seconds: 15, minutes: 0, hours: 0, days: 0, months: 0, years: 0}}
  end

  test "minutes only" do
    ast = eval_ok("8m")
    assert ast == {:duration, %{seconds: 0, minutes: 8, hours: 0, days: 0, months: 0, years: 0}}
  end

  test "hours only" do
    ast = eval_ok("2h")
    assert ast == {:duration, %{seconds: 0, minutes: 0, hours: 2, days: 0, months: 0, years: 0}}
  end

  test "days only" do
    ast = eval_ok("5d")
    assert ast == {:duration, %{seconds: 0, minutes: 0, hours: 0, days: 5, months: 0, years: 0}}
  end

  test "months only" do
    ast = eval_ok("3o")
    assert ast == {:duration, %{seconds: 0, minutes: 0, hours: 0, days: 0, months: 3, years: 0}}
  end

  test "years only" do
    ast = eval_ok("1y")
    assert ast == {:duration, %{seconds: 0, minutes: 0, hours: 0, days: 0, months: 0, years: 1}}
  end

  test "hours and minutes combined" do
    ast = eval_ok("2h30m")
    assert ast == {:duration, %{seconds: 0, minutes: 30, hours: 2, days: 0, months: 0, years: 0}}
  end

  test "hours and seconds combined" do
    ast = eval_ok("10h30s")
    assert ast == {:duration, %{seconds: 30, minutes: 0, hours: 10, days: 0, months: 0, years: 0}}
  end

  test "hours, minutes, and seconds" do
    ast = eval_ok("1h15m30s")
    assert ast == {:duration, %{seconds: 30, minutes: 15, hours: 1, days: 0, months: 0, years: 0}}
  end
end
