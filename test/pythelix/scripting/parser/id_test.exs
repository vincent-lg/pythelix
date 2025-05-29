defmodule Pythelix.Scripting.Parser.IDTest do
  @moduledoc """
  Module to test that variables are properly processed.
  """

  use Pythelix.ScriptingCase

  test "a one-letter lowercase variable name" do
    ast = eval_ok("i")
    assert ast == {:var, "i"}
  end

  test "a one-letter uppercase variable name" do
    ast = eval_ok("L")
    assert ast == {:var, "L"}
  end

  test "an ASCII-only variable name" do
    ast = eval_ok("nature")
    assert ast == {:var, "nature"}
  end

  test "a variable name containing accented letters" do
    ast = eval_ok("pré")
    assert ast == {:var, "pré"}
  end

  test "a variable name beginning with an accented letter" do
    ast = eval_ok("Éric")
    assert ast == {:var, "Éric"}
  end

  test "a negative one-letter lowercase variable name" do
    ast = eval_ok("-i")
    assert ast == {:neg, [{:var, "i"}]}
  end

  test "a negative one-letter uppercase variable name" do
    ast = eval_ok("-L")
    assert ast == {:neg, [{:var, "L"}]}
  end

  test "a negative ASCII-only variable name" do
    ast = eval_ok("-nature")
    assert ast == {:neg, [var: "nature"]}
  end

  test "a negative variable name containing accented letters" do
    ast = eval_ok("-pré")
    assert ast == {:neg, [{:var, "pré"}]}
  end

  test "a negative variable name beginning with an accented letter" do
    ast = eval_ok("-Éric")
    assert ast == {:neg, [{:var, "Éric"}]}
  end

  test "a variable containing part of a keyword" do
    ast = eval_ok("Truer")
    assert ast == {:var, "Truer"}
  end

  test "variable name with punctuation marks should fail" do
    eval_fail("some,thing")
  end

  test "variable name with utf-8 punctuation marks should fail" do
    eval_fail("some§thing")
  end

  test "variable name with monetary symbols should fail" do
    eval_fail("some$thing")
  end

  test "variable name with utf-8 monetary symbolbs should fail" do
    eval_fail("some€thing")
  end
end
