defmodule Pythelix.Scripting.ModuloTest do
  @moduledoc """
  Module to test the modulo operator (%).
  """

  use Pythelix.ScriptingCase

  test "modulo of two positive integers" do
    assert expr_ok("17 % 5") == 2
  end

  test "modulo of a negative integer takes the sign of the divisor" do
    assert expr_ok("-7 % 3") == 2
  end

  test "modulo by a negative integer takes the sign of the divisor" do
    assert expr_ok("7 % -3") == -2
  end

  test "modulo with floats" do
    assert expr_ok("7.5 % 2") == 1.5
  end

  test "modulo of a negative float takes the sign of the divisor" do
    assert expr_ok("-7.5 % 2") == 0.5
  end

  test "modulo wraps angles" do
    assert expr_ok("(90 - 180) % 360") == 270
  end

  test "modulo by zero raises ZeroDivisionError" do
    traceback = expr_fail("5 % 0")
    assert traceback.exception == ZeroDivisionError
  end

  test "modulo by float zero raises ZeroDivisionError" do
    traceback = expr_fail("5 % 0.0")
    assert traceback.exception == ZeroDivisionError
  end

  test "modulo on a string raises TypeError" do
    traceback = expr_fail(~s("%s" % 5))
    assert traceback.exception == TypeError
  end

  test "ZeroDivisionError can be caught" do
    script =
      run_ok("""
      try:
          value = 5 % 0
      except ZeroDivisionError:
          value = -1
      endtry
      """)

    assert script.variables["value"] == -1
  end
end
