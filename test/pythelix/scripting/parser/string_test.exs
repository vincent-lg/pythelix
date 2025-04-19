defmodule Pythelix.Scripting.Parser.StringTest do
  @moduledoc """
  Module to test that strings are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "a one-word string using single quotes" do
    ast = eval_ok("'thing'")
    assert ast == "thing"
  end

  test "a multiple-word string using single quotes" do
    ast = eval_ok("'this thing'")
    assert ast == "this thing"
  end

  test "a multiple-word string using single quotes and containing an escaped single quote" do
    ast = eval_ok("'this thing\\'s great'")
    assert ast == "this thing's great"
  end

  test "a multiple-word string using single quotes and containg accented letters" do
    ast = eval_ok("'on est bientôt en été'")
    assert ast == "on est bientôt en été"
  end

  test "a multiple-word string using single quotes and containg accented letters and double quotes" do
    ast = eval_ok("'on est \"bientôt\\\" en été'")
    assert ast == "on est \"bientôt\" en été"
  end

  test "a multiple-word string using single quotes and containg escape newsline" do
    ast = eval_ok("'bientôt\\nété'")
    assert ast == "bientôt\nété"
  end

  test "a single-quoted string with an unescape newsline should fail" do
    eval_fail("'abc\nde'")
  end

  test "a one-word string using double quotes" do
    ast = eval_ok("\"thing\"")
    assert ast == "thing"
  end

  test "a multiple-word string using double quotes" do
    ast = eval_ok("\"this thing\"")
    assert ast == "this thing"
  end

  test "a multiple-word string using double quotes and containing a single quote" do
    ast = eval_ok("\"this thing's great\"")
    assert ast == "this thing's great"
  end

  test "a multiple-word string using double quotes and containg accented letters" do
    ast = eval_ok("\"on est bientôt en été\"")
    assert ast == "on est bientôt en été"
  end

  test "a multiple-word string using double quotes and containg accented letters and escaped quotes" do
    ast = eval_ok("\"on est \\\"bientôt\\\" en été\"")
    assert ast == "on est \"bientôt\" en été"
  end

  test "a multiple-word string using double quotes and containg escape newsline" do
    ast = eval_ok("\"bientôt\\nété\"")
    assert ast == "bientôt\nété"
  end

  test "a double-quoted string with an unescape newsline should fail" do
    eval_fail("\"abc\nde\"")
  end
end
