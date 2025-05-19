defmodule Pythelix.Scripting.Namespace.ListTest do
  @moduledoc """
  Module to test the list API.
  """

  use Pythelix.ScriptingCase

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
        values = [true, 2 * 2, -3.2, 'ok']
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
end
