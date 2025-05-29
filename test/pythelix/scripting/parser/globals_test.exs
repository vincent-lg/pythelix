defmodule Pythelix.Scripting.Parser.GlobalsTest do
  @moduledoc """
  Module to test that globals are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "True should parse" do
    ast = eval_ok("True")
    assert ast == true
  end

  test "False should parse" do
    ast = eval_ok("False")
    assert ast == false
  end

  test "None should parse" do
    ast = eval_ok("None")
    assert ast == :none
  end
end
