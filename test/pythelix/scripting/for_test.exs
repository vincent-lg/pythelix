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
