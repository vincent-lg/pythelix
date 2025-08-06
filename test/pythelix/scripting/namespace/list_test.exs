defmodule Pythelix.Scripting.Namespace.ListTest do
  @moduledoc """
  Module to test the list API.
  """

  use Pythelix.ScriptingCase

  describe "__contains__" do
    test "in is True" do
      value = expr_ok("5 in [3, 4, 5]")
      assert value == true
    end

    test "in is False" do
      value = expr_ok("3 in [4, 5]")
      assert value == false
    end

    test "not in is True" do
      value = expr_ok("3 not in [4, 5]")
      assert value == true
    end

    test "not in is False" do
      value = expr_ok("5 not in [3, 4, 5]")
      assert value == false
    end
  end

  describe "creation" do
    test "an empty list" do
      script =
        run("""
        values = []
        """)

      assert Script.get_variable_value(script, "values") == []
    end

    test "a list with one number" do
      script =
        run("""
        values = [2]
        """)

      assert Script.get_variable_value(script, "values") == [2]
    end

    test "a list with one operation" do
      script =
        run("""
        values = [2 + 2]
        """)

      assert Script.get_variable_value(script, "values") == [4]
    end

    test "a list with one string" do
      script =
        run("""
        values = ["ok"]
        """)

      assert Script.get_variable_value(script, "values") == ["ok"]
    end

    test "a list with two numbers" do
      script =
        run("""
        values = [8, -3]
        """)

      assert Script.get_variable_value(script, "values") == [8, -3]
    end

    test "a list with one operation and one number" do
      script =
        run("""
        values = [2 + 2, 130]
        """)

      assert Script.get_variable_value(script, "values") == [4, 130]
    end

    test "a list with two strings" do
      script =
        run("""
        values = ["hello", "world"]
        """)

      assert Script.get_variable_value(script, "values") == ["hello", "world"]
    end

    test "a list with different types" do
      script =
        run("""
        values = [True, 2 * 2, -3.2, 'ok']
        """)

      assert Script.get_variable_value(script, "values") == [true, 4, -3.2, "ok"]
    end
  end

  describe "append" do
    test "a number to an empty list" do
      script =
        run("""
        values = []
        values.append(2)
        """)

      assert Script.get_variable_value(script, "values") == [2]
    end

    test "a string to an empty list" do
      script =
        run("""
        values = []
        values.append('ok')
        """)

      assert Script.get_variable_value(script, "values") == ["ok"]
    end

    test "an operation to an empty list" do
      script =
        run("""
        values = []
        values.append(2 * 2)
        """)

      assert Script.get_variable_value(script, "values") == [4]
    end

    test "a number to a list with one ellement" do
      script =
        run("""
        values = ['ok']
        values.append(2)
        """)

      assert Script.get_variable_value(script, "values") == ["ok", 2]
    end

    test "a number to a list with two ellements" do
      script =
        run("""
        values = [1, 2]
        values.append(10 - (5 + 2))
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3]
    end

    test "several times to a list with ellements" do
      script =
        run("""
        values = [1, 2]
        values.append(10 - (5 + 2))
        values.append(2 * 2 + 3 - 3)
        values.append(2 * 2 + 1)
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3, 4, 5]
    end
  end

  describe "clear" do
    test "empty list" do
      script =
        run("""
        values = []
        values.clear()
        """)

      assert Script.get_variable_value(script, "values") == []
    end

    test "list with elements" do
      script =
        run("""
        values = [1, 2, 3, "hello"]
        values.clear()
        """)

      assert Script.get_variable_value(script, "values") == []
    end
  end

  describe "copy" do
    test "empty list" do
      value = expr_ok("l = []\nl.copy()")
      assert value == []
    end

    test "list with elements" do
      value = expr_ok("l = [1, 2, 'hello']\nl.copy()")
      assert value == [1, 2, "hello"]
    end

    test "copy is independent" do
      script =
        run("""
        original = [1, 2, 3]
        copied = original.copy()
        original.append(4)
        """)

      assert Script.get_variable_value(script, "original") == [1, 2, 3, 4]
      assert Script.get_variable_value(script, "copied") == [1, 2, 3]
    end
  end

  describe "count" do
    test "count in empty list" do
      value = expr_ok("l = []\nl.count(5)")
      assert value == 0
    end

    test "count non-existing element" do
      value = expr_ok("l = [1, 2, 3]\nl.count(5)")
      assert value == 0
    end

    test "count single occurrence" do
      value = expr_ok("l = [1, 2, 3]\nl.count(2)")
      assert value == 1
    end

    test "count multiple occurrences" do
      value = expr_ok("l = [1, 2, 2, 3, 2]\nl.count(2)")
      assert value == 3
    end

    test "count string elements" do
      value = expr_ok("l = ['a', 'b', 'a', 'c']\nl.count('a')")
      assert value == 2
    end
  end

  describe "extend" do
    test "extend empty list with empty list" do
      script =
        run("""
        values = []
        values.extend([])
        """)

      assert Script.get_variable_value(script, "values") == []
    end

    test "extend empty list with elements" do
      script =
        run("""
        values = []
        values.extend([1, 2, 3])
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3]
    end

    test "extend list with elements" do
      script =
        run("""
        values = [1, 2]
        values.extend([3, 4, 5])
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3, 4, 5]
    end

    test "extend with mixed types" do
      script =
        run("""
        values = [1, 'hello']
        values.extend([True, 3.14])
        """)

      assert Script.get_variable_value(script, "values") == [1, "hello", true, 3.14]
    end
  end

  describe "index" do
    test "index in single element list" do
      value = expr_ok("l = [5]\nl.index(5)")
      assert value == 0
    end

    test "index of first element" do
      value = expr_ok("l = [1, 2, 3]\nl.index(1)")
      assert value == 0
    end

    test "index of last element" do
      value = expr_ok("l = [1, 2, 3]\nl.index(3)")
      assert value == 2
    end

    test "index with start parameter" do
      value = expr_ok("l = [1, 2, 1, 3]\nl.index(1, 1)")
      assert value == 2
    end

    test "index with start and stop parameters" do
      value = expr_ok("l = [1, 2, 1, 3, 1]\nl.index(1, 1, 4)")
      assert value == 2
    end

    test "index with negative start" do
      value = expr_ok("l = [1, 2, 3, 4]\nl.index(3, -2)")
      assert value == 2
    end
  end

  describe "insert" do
    test "insert at beginning" do
      script =
        run("""
        values = [1, 2, 3]
        values.insert(0, 0)
        """)

      assert Script.get_variable_value(script, "values") == [0, 1, 2, 3]
    end

    test "insert at end" do
      script =
        run("""
        values = [1, 2, 3]
        values.insert(3, 4)
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3, 4]
    end

    test "insert in middle" do
      script =
        run("""
        values = [1, 3]
        values.insert(1, 2)
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3]
    end

    test "insert with negative index" do
      script =
        run("""
        values = [1, 2, 3]
        values.insert(-1, 'x')
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, "x", 3]
    end

    test "insert beyond list length" do
      script =
        run("""
        values = [1, 2]
        values.insert(10, 'end')
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, "end"]
    end

    test "insert in empty list" do
      script =
        run("""
        values = []
        values.insert(0, 'first')
        """)

      assert Script.get_variable_value(script, "values") == ["first"]
    end
  end

  describe "pop" do
    test "pop from single element list" do
      script =
        run("""
        values = [5]
        result = values.pop()
        """)

      assert Script.get_variable_value(script, "values") == []
      assert Script.get_variable_value(script, "result") == 5
    end

    test "pop last element (default)" do
      script =
        run("""
        values = [1, 2, 3]
        result = values.pop()
        """)

      assert Script.get_variable_value(script, "values") == [1, 2]
      assert Script.get_variable_value(script, "result") == 3
    end

    test "pop first element" do
      script =
        run("""
        values = [1, 2, 3]
        result = values.pop(0)
        """)

      assert Script.get_variable_value(script, "values") == [2, 3]
      assert Script.get_variable_value(script, "result") == 1
    end

    test "pop middle element" do
      script =
        run("""
        values = [1, 2, 3]
        result = values.pop(1)
        """)

      assert Script.get_variable_value(script, "values") == [1, 3]
      assert Script.get_variable_value(script, "result") == 2
    end

    test "pop with negative index" do
      script =
        run("""
        values = [1, 2, 3]
        result = values.pop(-2)
        """)

      assert Script.get_variable_value(script, "values") == [1, 3]
      assert Script.get_variable_value(script, "result") == 2
    end
  end

  describe "remove" do
    test "remove single occurrence" do
      script =
        run("""
        values = [1, 2, 3]
        values.remove(2)
        """)

      assert Script.get_variable_value(script, "values") == [1, 3]
    end

    test "remove first occurrence of duplicate" do
      script =
        run("""
        values = [1, 2, 2, 3]
        values.remove(2)
        """)

      assert Script.get_variable_value(script, "values") == [1, 2, 3]
    end

    test "remove string element" do
      script =
        run("""
        values = ['a', 'b', 'c']
        values.remove('b')
        """)

      assert Script.get_variable_value(script, "values") == ["a", "c"]
    end
  end

  describe "reverse" do
    test "reverse empty list" do
      script =
        run("""
        values = []
        values.reverse()
        """)

      assert Script.get_variable_value(script, "values") == []
    end

    test "reverse single element list" do
      script =
        run("""
        values = [5]
        values.reverse()
        """)

      assert Script.get_variable_value(script, "values") == [5]
    end

    test "reverse multiple elements" do
      script =
        run("""
        values = [1, 2, 3, 4]
        values.reverse()
        """)

      assert Script.get_variable_value(script, "values") == [4, 3, 2, 1]
    end

    test "reverse mixed types" do
      script =
        run("""
        values = [1, 'hello', True, 3.14]
        values.reverse()
        """)

      assert Script.get_variable_value(script, "values") == [3.14, true, "hello", 1]
    end
  end

  describe "sort" do
    test "sort empty list" do
      script =
        run("""
        values = []
        values.sort()
        """)

      assert Script.get_variable_value(script, "values") == []
    end

    test "sort single element list" do
      script =
        run("""
        values = [5]
        values.sort()
        """)

      assert Script.get_variable_value(script, "values") == [5]
    end

    test "sort numbers ascending" do
      script =
        run("""
        values = [3, 1, 4, 1, 5]
        values.sort()
        """)

      assert Script.get_variable_value(script, "values") == [1, 1, 3, 4, 5]
    end

    test "sort numbers descending" do
      script =
        run("""
        values = [3, 1, 4, 1, 5]
        values.sort(True)
        """)

      assert Script.get_variable_value(script, "values") == [5, 4, 3, 1, 1]
    end

    test "sort strings" do
      script =
        run("""
        values = ['cherry', 'apple', 'banana']
        values.sort()
        """)

      assert Script.get_variable_value(script, "values") == ["apple", "banana", "cherry"]
    end

    test "sort strings descending" do
      script =
        run("""
        values = ['cherry', 'apple', 'banana']
        values.sort(True)
        """)

      assert Script.get_variable_value(script, "values") == ["cherry", "banana", "apple"]
    end
  end
end
