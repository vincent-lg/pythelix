defmodule Pythelix.Scripting.VariableTest do
  @moduledoc """
  Module to test that variables are properly created.
  """

  use Pythelix.ScriptingCase

  test "assign a single positive integer to a variable" do
    script = run("value = 3")
    assert script.variables == %{"value" => 3}
  end

  test "assign a single negative integer to a variable" do
    script = run("ça = -19")
    assert script.variables == %{"ça" => -19}
  end

  test "assign a single positive float to a variable" do
    script = run("value = 38.59")
    assert script.variables == %{"value" => 38.59}
  end

  test "assign a single negative float to a variable" do
    script = run("ça = -0.5")
    assert script.variables == %{"ça" => -0.5}
  end

  test "assign an addition to a variable" do
    script = run("calcul = 5 + 12")
    assert script.variables == %{"calcul" => 17}
  end

  test "assign a subtraction to a variable" do
    script = run("calcul = -5 - 12")
    assert script.variables == %{"calcul" => -17}
  end

  test "assign a multiplication to a variable" do
    script = run("calcul = 2*8")
    assert script.variables == %{"calcul" => 16}
  end

  test "assign a division to a variable" do
    script = run("calcul = 10/ 2")
    assert script.variables == %{"calcul" => 5.0}
  end

  test "check operator precedence with * on the right" do
    script = run("calcul = 3 + 4 * 5")
    assert script.variables == %{"calcul" => 23}
  end

  test "check operator precedence with * on the left" do
    script = run("calcul = 3 * 4 + 5")
    assert script.variables == %{"calcul" => 17}
  end

  test "check that parenthesis have higher priority than mul on the right" do
    script = run("calcul = (3 + 4) * 5")
    assert script.variables == %{"calcul" => 35}
  end

  test "check that parenthesis have higher priority than mul on the left" do
    script = run("calcul = 3 * (4 + 5)")
    assert script.variables == %{"calcul" => 27}
  end

  test "check that operator < returns a bool" do
    script = run("cond = 2 < 8")
    assert script.variables == %{"cond" => true}
  end

  test "check that operator <= returns a bool" do
    script = run("cond = -3 <= 4")
    assert script.variables == %{"cond" => true}
  end

  test "check that operator > returns a bool" do
    script = run("cond = 3 > -1.5")
    assert script.variables == %{"cond" => true}
  end

  test "check that operator >= returns a bool" do
    script = run("cond = 4 >= 4")
    assert script.variables == %{"cond" => true}
  end

  test "assess a range with several <, 1" do
    script = run("cond = 0 < 5 < 10")
    assert script.variables == %{"cond" => true}
  end

  test "assess a range with several <, 2" do
    script = run("cond = 30 < 5 <= 10")
    assert script.variables == %{"cond" => false}
  end

  test "assess a range with several <, 3" do
    script = run("cond = 0 < 5 <= -3")
    assert script.variables == %{"cond" => false}
  end

  test "assess a range with several >, 1" do
    script = run("cond = 10 > 5 > 0")
    assert script.variables == %{"cond" => true}
  end

  test "assess a range with several >, 2" do
    script = run("cond = 10 > 5 >= 30")
    assert script.variables == %{"cond" => false}
  end

  test "assess a range with several >, 3" do
    script = run("cond = -3 > 5 >= -3")
    assert script.variables == %{"cond" => false}
  end

  test "assign not true" do
    script = run("cond = not true")
    assert script.variables == %{"cond" => false}
  end

  test "assign not false" do
    script = run("cond = not false")
    assert script.variables == %{"cond" => true}
  end
end
