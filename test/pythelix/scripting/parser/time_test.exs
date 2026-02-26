defmodule Pythelix.Scripting.Parser.TimeTest do
  @moduledoc """
  Module to test that time literals are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "a simple time with hours and minutes" do
    ast = eval_ok("15:00")
    assert ast == {:time, 15, 0, 0}
  end

  test "a time with hours, minutes, and seconds" do
    ast = eval_ok("8:30:45")
    assert ast == {:time, 8, 30, 45}
  end

  test "midnight" do
    ast = eval_ok("0:00")
    assert ast == {:time, 0, 0, 0}
  end

  test "a time with single-digit parts" do
    ast = eval_ok("9:05")
    assert ast == {:time, 9, 5, 0}
  end

  test "a time with all zeros" do
    ast = eval_ok("0:00:00")
    assert ast == {:time, 0, 0, 0}
  end

  test "a time in braces is a set, not a dict" do
    set = expr_ok("{15:00}")
    assert %MapSet{} = set
  end

  test "space after colon is a dict, not a time" do
    dict = expr_ok("{15: 00}")
    assert %Pythelix.Scripting.Object.Dict{} = dict
  end
end
