defmodule Pythelix.Scripting.Parser.NumberTest do
  @moduledoc """
  Module to test that numbers are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "a single digit should parse" do
    ast = eval_ok("1")
    assert ast == 1
  end

  test "several digits should parse" do
    ast = eval_ok("138")
    assert ast == 138
  end

  test "a single negative digit should parse" do
    ast = eval_ok("-1")
    assert ast == -1
  end

  test "several negative digits should parse" do
    ast = eval_ok("-138")
    assert ast == -138
  end

  test "a floating point number with one digit should parser" do
    ast = eval_ok("0.5")
    assert ast == 0.5
  end

  test "a floating point number with two digits should parser" do
    ast = eval_ok("10.52")
    assert ast == 10.52
  end

  test "a negative floating point number with one digit should parser" do
    ast = eval_ok("-0.5")
    assert ast == -0.5
  end

  test "a negative floating point number with two digits should parser" do
    ast = eval_ok("-10.52")
    assert ast == -10.52
  end
end
