defmodule Pythelix.Scripting.Namespace.TupleTest do
  @moduledoc """
  Module to test the tuple API.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.Tuple

  describe "creation" do
    test "an empty tuple" do
      script =
        run_ok("""
        values = ()
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: []}
    end

    test "a tuple with one element" do
      script =
        run_ok("""
        values = (1,)
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1]}
    end

    test "a tuple with two elements" do
      script =
        run_ok("""
        values = (1, 2)
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1, 2]}
    end

    test "a tuple with trailing comma" do
      script =
        run_ok("""
        values = (1, 2,)
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1, 2]}
    end

    test "a nested tuple" do
      script =
        run_ok("""
        values = ((1, 2), 3)
        """)

      inner = %Tuple{elements: [1, 2]}
      assert Script.get_variable_value(script, "values") == %Tuple{elements: [inner, 3]}
    end

    test "a tuple with an operation" do
      script =
        run_ok("""
        values = (1 + 2,)
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [3]}
    end

    test "a tuple with mixed types" do
      script =
        run_ok("""
        values = (1, 'hello', True)
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1, "hello", true]}
    end
  end

  describe "not a tuple" do
    test "grouping expression" do
      value = expr_ok("(1 + 2) * 3")
      assert value == 9
    end

    test "simple grouping" do
      value = expr_ok("(5)")
      assert value == 5
    end
  end

  describe "__contains__" do
    test "in is True" do
      value = expr_ok("5 in (3, 4, 5)")
      assert value == true
    end

    test "in is False" do
      value = expr_ok("3 in (4, 5)")
      assert value == false
    end

    test "not in is True" do
      value = expr_ok("3 not in (4, 5)")
      assert value == true
    end

    test "not in is False" do
      value = expr_ok("5 not in (3, 4, 5)")
      assert value == false
    end
  end

  describe "__getitem__" do
    test "get first element" do
      value = expr_ok("t = (10, 20, 30)\nt[0]")
      assert value == 10
    end

    test "get last element" do
      value = expr_ok("t = (10, 20, 30)\nt[2]")
      assert value == 30
    end

    test "get with negative index" do
      value = expr_ok("t = (10, 20, 30)\nt[-1]")
      assert value == 30
    end

    test "index out of range" do
      traceback = expr_fail("t = (1, 2)\nt[5]")
      assert traceback.exception == IndexError
    end
  end

  describe "immutability" do
    test "__setitem__ raises TypeError" do
      traceback = expr_fail("t = (1, 2, 3)\nt[0] = 99")
      assert traceback.exception == TypeError
      assert traceback.message =~ "does not support item assignment"
    end
  end

  describe "__repr__" do
    test "empty tuple" do
      value = expr_ok("repr(())")
      assert value == "()"
    end

    test "single element tuple" do
      value = expr_ok("repr((1,))")
      assert value == "(1,)"
    end

    test "multi element tuple" do
      value = expr_ok("repr((1, 2, 3))")
      assert value == "(1, 2, 3)"
    end
  end

  describe "__str__" do
    test "tuple str" do
      value = expr_ok("str((1, 2))")
      assert value == "(1, 2)"
    end
  end

  describe "__bool__" do
    test "empty tuple is False" do
      value = expr_ok("bool(())")
      assert value == false
    end

    test "non-empty tuple is True" do
      value = expr_ok("bool((1,))")
      assert value == true
    end
  end

  describe "count" do
    test "count in empty tuple" do
      value = expr_ok("t = ()\nt.count(5)")
      assert value == 0
    end

    test "count non-existing element" do
      value = expr_ok("t = (1, 2, 3)\nt.count(5)")
      assert value == 0
    end

    test "count multiple occurrences" do
      value = expr_ok("t = (1, 2, 2, 3, 2)\nt.count(2)")
      assert value == 3
    end
  end

  describe "index" do
    test "index of first element" do
      value = expr_ok("t = (1, 2, 3)\nt.index(1)")
      assert value == 0
    end

    test "index of last element" do
      value = expr_ok("t = (1, 2, 3)\nt.index(3)")
      assert value == 2
    end

    test "value not in tuple" do
      traceback = expr_fail("t = (1, 2, 3)\nt.index(5)")
      assert traceback.exception == ValueError
    end
  end

  describe "len" do
    test "empty tuple" do
      value = expr_ok("len(())")
      assert value == 0
    end

    test "tuple with elements" do
      value = expr_ok("len((1, 2, 3))")
      assert value == 3
    end

    test "tuple with one element" do
      value = expr_ok("len((42,))")
      assert value == 1
    end
  end

  describe "multiline" do
    test "a tuple on multiple lines" do
      script =
        run_ok("""
        values = (
          1,
          2,
          3,
        )
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1, 2, 3]}
    end
  end

  describe "implicit tuple creation" do
    test "return a, b returns a 2-tuple" do
      value = expr_ok("a = 1\nb = 2\nreturn a, b")
      assert value == %Tuple{elements: [1, 2]}
    end

    test "a, b as a raw statement produces a tuple" do
      value = expr_ok("a = 1\nb = 2\na, b")
      assert value == %Tuple{elements: [1, 2]}
    end
  end

  describe "tuple unpacking" do
    test "a, b = (1, 2) assigns correctly" do
      script =
        run_ok("""
        a, b = (1, 2)
        """)

      assert Script.get_variable_value(script, "a") == 1
      assert Script.get_variable_value(script, "b") == 2
    end

    test "(a, b) = (3, 4) assigns correctly" do
      script =
        run_ok("""
        (a, b) = (3, 4)
        """)

      assert Script.get_variable_value(script, "a") == 3
      assert Script.get_variable_value(script, "b") == 4
    end

    test "a, b = 1, 2 uses implicit tuple on RHS" do
      script =
        run_ok("""
        a, b = 1, 2
        """)

      assert Script.get_variable_value(script, "a") == 1
      assert Script.get_variable_value(script, "b") == 2
    end

    test "a, b, c = (1, 2, 3) assigns all three" do
      script =
        run_ok("""
        a, b, c = (1, 2, 3)
        """)

      assert Script.get_variable_value(script, "a") == 1
      assert Script.get_variable_value(script, "b") == 2
      assert Script.get_variable_value(script, "c") == 3
    end

    test "(a,) = (5,) single-element unpack" do
      script =
        run_ok("""
        (a,) = (5,)
        """)

      assert Script.get_variable_value(script, "a") == 5
    end

    test "a, b = [1, 2] unpacks a list" do
      script =
        run_ok("""
        a, b = [1, 2]
        """)

      assert Script.get_variable_value(script, "a") == 1
      assert Script.get_variable_value(script, "b") == 2
    end

    test "length mismatch raises ValueError" do
      traceback = expr_fail("a, b = (1, 2, 3)")
      assert traceback.exception == ValueError
    end

    test "wrong type raises TypeError" do
      traceback = expr_fail("a, b = 5")
      assert traceback.exception == TypeError
    end

    test "unpack return value from function" do
      script = run_ok("a, b = tuple([1, 2])")
      assert Script.get_variable_value(script, "a") == 1
      assert Script.get_variable_value(script, "b") == 2
    end
  end

  describe "tuple() constructor" do
    test "empty tuple" do
      script =
        run_ok("""
        values = tuple()
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: []}
    end

    test "tuple from list" do
      script =
        run_ok("""
        values = tuple([1, 2, 3])
        """)

      assert Script.get_variable_value(script, "values") == %Tuple{elements: [1, 2, 3]}
    end
  end
end
