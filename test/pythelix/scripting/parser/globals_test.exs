defmodule Pythelix.Scripting.Parser.GlobalsTest do
  @moduledoc """
  Module to test that globals are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "true should parse" do
    ast = eval_ok("true")
    assert ast == true
  end

  test "false should parse" do
    ast = eval_ok("false")
    assert ast == false
  end
end
