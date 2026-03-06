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
