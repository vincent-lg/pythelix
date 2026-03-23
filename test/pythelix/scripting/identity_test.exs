defmodule Pythelix.Scripting.IdentityTest do
  @moduledoc """
  Module to test the `is` and `is not` identity operators.
  """

  use Pythelix.ScriptingCase

  describe "is operator" do
    test "None is None" do
      assert expr_ok("None is None") == true
    end

    test "True is True" do
      assert expr_ok("True is True") == true
    end

    test "False is False" do
      assert expr_ok("False is False") == true
    end

    test "integer is same integer" do
      assert expr_ok("1 is 1") == true
    end

    test "string is same string" do
      assert expr_ok("\"hello\" is \"hello\"") == true
    end

    test "two empty lists are not identical" do
      assert expr_ok("[] is []") == false
    end

    test "two empty dicts are not identical" do
      assert expr_ok("{} is {}") == false
    end

    test "variable is itself" do
      script =
        run_ok("""
        a = [1, 2]
        result = a is a
        """)

      assert script.variables["result"] == true
    end

    test "two variables with same list value are not identical" do
      script =
        run_ok("""
        a = [1, 2]
        b = [1, 2]
        result = a is b
        """)

      assert script.variables["result"] == false
    end

    test "aliased variable is identical" do
      script =
        run_ok("""
        a = [1, 2]
        b = a
        result = a is b
        """)

      assert script.variables["result"] == true
    end

    test "None variable is None" do
      script =
        run_ok("""
        a = None
        result = a is None
        """)

      assert script.variables["result"] == true
    end
  end

  describe "is not operator" do
    test "None is not None is false" do
      assert expr_ok("None is not None") == false
    end

    test "1 is not 2" do
      assert expr_ok("1 is not 2") == true
    end

    test "1 is not 1 is false" do
      assert expr_ok("1 is not 1") == false
    end

    test "two empty lists are not identical" do
      assert expr_ok("[] is not []") == true
    end

    test "variable is not itself is false" do
      script =
        run_ok("""
        a = [1, 2]
        result = a is not a
        """)

      assert script.variables["result"] == false
    end

    test "two different lists are not identical" do
      script =
        run_ok("""
        a = [1, 2]
        b = [1, 2]
        result = a is not b
        """)

      assert script.variables["result"] == true
    end
  end

  describe "is in conditions" do
    test "if value is None" do
      script =
        run_ok("""
        a = None
        if a is None:
          result = "none"
        else:
          result = "not none"
        endif
        """)

      assert script.variables["result"] == "none"
    end

    test "if value is not None" do
      script =
        run_ok("""
        a = 5
        if a is not None:
          result = "not none"
        else:
          result = "none"
        endif
        """)

      assert script.variables["result"] == "not none"
    end
  end
end
