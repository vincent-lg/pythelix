defmodule Pythelix.Scripting.NegationTest do
  @moduledoc """
  Module to test the unary minus operator (-x).
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Interpreter.Script

  defmodule Negatable do
    @moduledoc false

    def m___neg__(script, _self, [], _kwargs), do: {script, "negated"}
  end

  defp run_with(code, variables) do
    script =
      Enum.reduce(variables, run_ok(""), fn {name, value}, script ->
        Script.write_variable(script, name, value)
      end)

    Pythelix.Scripting.run(code, script: script)
  end

  test "negate a negative literal" do
    assert expr_ok("-3") == -3
  end

  test "negate a variable" do
    script =
      run_ok("""
      x = 3
      y = -x
      """)

    assert script.variables["y"] == -3
  end

  test "negate a float variable" do
    script =
      run_ok("""
      x = 2.5
      y = -x
      """)

    assert script.variables["y"] == -2.5
  end

  test "negate a method call" do
    assert expr_ok(~s[-"abc".find("c")]) == -2
  end

  test "negate a function call" do
    assert expr_ok(~s[-int("4")]) == -4
  end

  test "negate a parenthesized expression" do
    assert expr_ok("-(2 + 3)") == -5
  end

  test "negate twice" do
    script =
      run_ok("""
      x = 3
      y = --x
      """)

    assert script.variables["y"] == 3
  end

  test "multiply by a negated variable" do
    script =
      run_ok("""
      x = 3
      y = 2 * -x
      """)

    assert script.variables["y"] == -6
  end

  test "unary minus binds looser than **" do
    script =
      run_ok("""
      x = 3
      y = -x ** 2
      z = -2 ** 2
      """)

    assert script.variables["y"] == -9
    assert script.variables["z"] == -4
  end

  test "a negated exponent" do
    script =
      run_ok("""
      x = 1
      y = 2 ** -x
      """)

    assert script.variables["y"] == 0.5
  end

  test "a line starting with minus is a new statement" do
    assert expr_ok("x = 3\n-x") == -3
  end

  test "a line starting with minus does not change the previous assignment" do
    script =
      run_ok("""
      x = 3
      -x
      y = x
      """)

    assert script.variables["y"] == 3
  end

  test "binary minus still works" do
    script =
      run_ok("""
      x = 3
      y = 10 - x
      z = 10 -
          x
      """)

    assert script.variables["y"] == 7
    assert script.variables["z"] == 7
  end

  test "negation goes through __neg__ for other types" do
    script = run_with("y = -v", [{"v", Negatable}])
    assert script.error == nil
    assert script.variables["y"] == "negated"
  end

  test "negating a string raises TypeError" do
    traceback = expr_fail(~s(-"text"))
    assert traceback.exception == TypeError
  end
end
