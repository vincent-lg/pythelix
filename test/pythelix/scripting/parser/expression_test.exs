defmodule Pythelix.Scripting.Parser.ExpressionTest do
  @moduledoc """
  Module to test that expressions (operations) are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "test add numbers" do
    ast = eval_ok("5 + 29.3")
    assert ast == {:+, [5, 29.3]}
  end

  test "test minus numbers" do
    ast = eval_ok("-8 - 29")
    assert ast == {:-, [-8, 29]}
  end

  test "test multiply numbers" do
    ast = eval_ok("5 * -4")
    assert ast == {:*, [5, -4]}
  end

  test "test divide numbers" do
    ast = eval_ok("10 / 2")
    assert ast == {:/, [10, 2]}
  end

  test "test power numbers" do
    ast = eval_ok("5 ** 2")
    assert ast == {:**, [5, 2]}
  end

  test "test add numbers and variables" do
    ast = eval_ok("5 + variable")
    assert ast == {:+, [5, {:var, "variable"}]}
  end

  test "test minus numbers and variables" do
    ast = eval_ok("nombre - -29")
    assert ast == {:-, [{:var, "nombre"}, -29]}
  end

  test "test multiply numbers and variables" do
    ast = eval_ok("5 * nàme")
    assert ast == {:*, [5, {:var, "nàme"}]}
  end

  test "test divide numbers and variables" do
    ast = eval_ok("a_bc / 2")
    assert ast == {:/, [{:var, "a_bc"}, 2]}
  end

  test "test power numbers and variables" do
    ast = eval_ok("variable ** 3")
    assert ast == {:**, [{:var, "variable"}, 3]}
  end

  test "* has more precedence than +, left" do
    ast = eval_ok("1 + 2 * 3")
    assert ast == {:+, [1, {:*, [2, 3]}]}
  end

  test "* has more precedence than +, right" do
    ast = eval_ok("1 * 2 + 3")
    assert ast == {:+, [{:*, [1, 2]}, 3]}
  end

  test "** has more precedence than *, left" do
    ast = eval_ok("2 * 3 ** 2")
    assert ast == {:*, [2, {:**, [3, 2]}]}
  end

  test "** has more precedence than *, right" do
    ast = eval_ok("2 ** 3 * 4")
    assert ast == {:*, [{:**, [2, 3]}, 4]}
  end

  test "** is right associative" do
    ast = eval_ok("2 ** 3 ** 2")
    assert ast == {:**, [2, {:**, [3, 2]}]}
  end

  test "compare lower than a number with addition" do
    ast = eval_ok("number + 3 < 4")
    assert ast == {:<, [{:+, [{:var, "number"}, 3]}, 4]}
  end

  test "compare lower than a number with multiplication" do
    ast = eval_ok("number * 3 < 4")
    assert ast == {:<, [{:*, [{:var, "number"}, 3]}, 4]}
  end

  test "compare lower than or equal a number with addition" do
    ast = eval_ok("number + 3 <= 4")
    assert ast == {:<=, [{:+, [{:var, "number"}, 3]}, 4]}
  end

  test "compare lower than or equal a number with multiplication" do
    ast = eval_ok("number * 3 <= 4")
    assert ast == {:<=, [{:*, [{:var, "number"}, 3]}, 4]}
  end

  test "compare greater than a number with addition" do
    ast = eval_ok("number + 3 > 4")
    assert ast == {:>, [{:+, [{:var, "number"}, 3]}, 4]}
  end

  test "compare greater than a number with multiplication" do
    ast = eval_ok("number * 3 > 4")
    assert ast == {:>, [{:*, [{:var, "number"}, 3]}, 4]}
  end

  test "compare greater than or equal a number with addition" do
    ast = eval_ok("number + 3 >= 4")
    assert ast == {:>=, [{:+, [{:var, "number"}, 3]}, 4]}
  end

  test "compare greater than or equal a number with multiplication" do
    ast = eval_ok("number * 3 >= 4")
    assert ast == {:>=, [{:*, [{:var, "number"}, 3]}, 4]}
  end

  test "a number between two extremes with lower" do
    ast = eval_ok("0 < number <= 10")
    assert ast == {:<=, [{:<, [0, {:var, "number"}]}, 10]}
  end

  test "a number between two extremes with greater" do
    ast = eval_ok("10 >= number > 0")
    assert ast == {:>, [{:>=, [10, {:var, "number"}]}, 0]}
  end

  test "== has less precedence than <, left" do
    ast = eval_ok("1 < 2 == 3")
    assert ast == {:==, [{:<, [1, 2]}, 3]}
  end

  test "== has less precedence than <, right" do
    ast = eval_ok("1 == 2 < 3")
    assert ast == {:==, [1, {:<, [2, 3]}]}
  end

  test "!= has less precedence than >, left" do
    ast = eval_ok("1 > 2 != 3")
    assert ast == {:!=, [{:>, [1, 2]}, 3]}
  end

  test "!= has less precedence than >, right" do
    ast = eval_ok("1 != 2 > 3")
    assert ast == {:!=, [1, {:>, [2, 3]}]}
  end

  test "or has less precedence than ==, left" do
    ast = eval_ok("1 == 2 or 3")
    assert ast == {:or, [{:==, [1, 2]}, 3]}
  end

  test "or has less precedence than ==, right" do
    ast = eval_ok("1 or 2 == 3")
    assert ast == {:or, [1, {:==, [2, 3]}]}
  end

  test "and has less precedence than or, left" do
    ast = eval_ok("1 or 2 and 3")
    assert ast == {:and, [{:or, [1, 2]}, 3]}
  end

  test "and has less precedence than or, right" do
    ast = eval_ok("1 and 2 or 3")
    assert ast == {:and, [1, {:or, [2, 3]}]}
  end

  test "not a bool in isolation" do
    ast = eval_ok("not True")
    assert ast == {:not, [true]}
  end

  test "not a number in isolation" do
    ast = eval_ok("not 2")
    assert ast == {:not, [2]}
  end

  test "not a bool in and with parents" do
    ast = eval_ok("1 and (not True)")
    assert ast == {:and, [1, {:not, [true]}]}
  end

  test "not a number in or with parents" do
    ast = eval_ok("1 or (not 2)")
    assert ast == {:or, [1, {:not, [2]}]}
  end

  test "not a bool in and without parents" do
    ast = eval_ok("1 and not True")
    assert ast == {:and, [1, {:not, [true]}]}
  end

  test "not a number in or without parents" do
    ast = eval_ok("1 or not 2")
    assert ast == {:or, [1, {:not, [2]}]}
  end

  test "parents should bring priority of + over *" do
    ast = eval_ok("(1 + 2) * 3")
    assert ast == {:*, [{:+, [1, 2]}, 3]}
  end
end
