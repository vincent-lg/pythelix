defmodule Pythelix.Scripting.Namespace.BuiltinTest do
  @moduledoc """
  Module to test builtin functions (int, float, list, etc.).
  """

  use Pythelix.ScriptingCase

  describe "int()" do
    test "int of an integer is itself" do
      assert expr_ok("int(42)") == 42
    end

    test "int of a negative integer is itself" do
      assert expr_ok("int(-7)") == -7
    end

    test "int of a float truncates" do
      assert expr_ok("int(3.9)") == 3
    end

    test "int of a negative float truncates toward zero" do
      assert expr_ok("int(-3.9)") == -3
    end

    test "int of True is 1" do
      assert expr_ok("int(True)") == 1
    end

    test "int of False is 0" do
      assert expr_ok("int(False)") == 0
    end

    test "int of a numeric string" do
      assert expr_ok(~s[int("42")]) == 42
    end

    test "int of a negative numeric string" do
      assert expr_ok(~s[int("-7")]) == -7
    end

    test "int of a non-numeric string raises ValueError" do
      assert expr_fail(~s[int("abc")]) != nil
    end

    test "int of a list raises TypeError" do
      assert expr_fail("int([1, 2])") != nil
    end
  end

  describe "float()" do
    test "float of a float is itself" do
      assert expr_ok("float(3.14)") == 3.14
    end

    test "float of an integer widens to float" do
      assert expr_ok("float(5)") == 5.0
    end

    test "float of True is 1.0" do
      assert expr_ok("float(True)") == 1.0
    end

    test "float of False is 0.0" do
      assert expr_ok("float(False)") == 0.0
    end

    test "float of a numeric string" do
      assert expr_ok(~s[float("2.5")]) == 2.5
    end

    test "float of a non-numeric string raises ValueError" do
      assert expr_fail(~s[float("abc")]) != nil
    end

    test "float of a list raises TypeError" do
      assert expr_fail("float([1])") != nil
    end
  end

  describe "list()" do
    test "list with no argument returns empty list" do
      assert expr_ok("list()") == []
    end

    test "list of a list returns the same elements" do
      assert expr_ok("list([1, 2, 3])") == [1, 2, 3]
    end

    test "list of a tuple returns its elements" do
      script =
        run_ok("""
        t = tuple([1, 2, 3])
        result = list(t)
        """)

      assert Script.get_variable_value(script, "result") == [1, 2, 3]
    end

    test "list of a set returns a list of all elements" do
      script =
        run_ok("""
        s = set([1, 2, 3])
        result = list(s)
        """)

      assert Enum.sort(Script.get_variable_value(script, "result")) == [1, 2, 3]
    end

    test "list of a dict returns its keys" do
      script =
        run_ok("""
        d = {"a": 1, "b": 2}
        result = list(d)
        """)

      assert Enum.sort(Script.get_variable_value(script, "result")) == ["a", "b"]
    end

    test "list of a string returns its characters" do
      assert expr_ok(~s[list("abc")]) == ["a", "b", "c"]
    end

    test "list of an integer raises TypeError" do
      assert expr_fail("list(42)") != nil
    end
  end
end
