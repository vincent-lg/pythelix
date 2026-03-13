defmodule Pythelix.Scripting.ForTest do
  @moduledoc """
  Module to test that for loops are properly created.
  """

  use Pythelix.ScriptingCase

  test "sums integers in a list" do
    script =
      run("""
      sum = 0
      for number in [1, 2, 3, 4, 5]:
        sum += number
      done
      """)

    assert script.variables["sum"] == 15
  end

  test "iterates over a tuple" do
    script =
      run("""
      sum = 0
      for number in (1, 2, 3, 4, 5):
        sum += number
      done
      """)

    assert script.variables["sum"] == 15
  end

  test "iterates over a set" do
    script =
      run("""
      result = []
      for item in {10, 20, 30}:
        result.append(item)
      done
      """)

    result = script.variables["result"] |> Store.get_value()
    assert Enum.sort(result) == [10, 20, 30]
  end

  test "iterates over a dict (yields keys)" do
    script =
      run("""
      keys = []
      d = {"a": 1, "b": 2, "c": 3}
      for key in d:
        keys.append(key)
      done
      """)

    keys = script.variables["keys"] |> Store.get_value()
    assert Enum.sort(keys) == ["a", "b", "c"]
  end

  test "unpacks tuples in for loop" do
    script =
      run("""
      keys = []
      values = []
      d = {"a": 1, "b": 2, "c": 3}
      for key, value in d.items():
        keys.append(key)
        values.append(value)
      done
      """)

    keys = script.variables["keys"] |> Store.get_value()
    values = script.variables["values"] |> Store.get_value()
    assert Enum.sort(keys) == ["a", "b", "c"]
    assert Enum.sort(values) == [1, 2, 3]
  end

  test "unpacks list of lists in for loop" do
    script =
      run("""
      xs = []
      ys = []
      for x, y in [[1, 10], [2, 20], [3, 30]]:
        xs.append(x)
        ys.append(y)
      done
      """)

    assert script.variables["xs"] |> Store.get_value() == [1, 2, 3]
    assert script.variables["ys"] |> Store.get_value() == [10, 20, 30]
  end

  test "unpacks three variables in for loop" do
    script =
      run("""
      result = 0
      for a, b, c in [(1, 2, 3), (4, 5, 6)]:
        result += a + b + c
      done
      """)

    assert script.variables["result"] == 21
  end

  test "sums integers in nested loops" do
    script =
      run("""
      sum = 0
      to_add = [[1, 2, 3], [4, 5], [6, 7, 4 * 2]]
      for sub_add in to_add:
        for number in sub_add:
          sum += number
        done
      done
      """)

    assert script.variables["sum"] == 36
    assert Script.get_variable_value(script, "sub_add") == [6, 7, 8]
  end
end
