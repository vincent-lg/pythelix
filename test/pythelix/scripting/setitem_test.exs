defmodule Pythelix.Scripting.SetitemTest do
  @moduledoc """
  Module to test item assignment (`x[i] = ...`), including through attributes.
  """

  use Pythelix.ScriptingCase
  alias Pythelix.Record

  defp stored_attribute(script, variable, attribute) do
    id = Script.get_variable_value(script, variable).id
    Record.Cache.commit_and_clear()

    id
    |> Record.get_entity()
    |> Record.get_attribute(attribute)
  end

  describe "on a variable" do
    test "set an item in a list" do
      script =
        run("""
        items = [1, 2]
        items[0] = 5
        """)

      assert Script.get_variable_value(script, "items") == [5, 2]
    end

    test "set an item in a nested list" do
      script =
        run("""
        items = [[1, 2], [3, 4]]
        items[1][0] = 5
        """)

      assert Script.get_variable_value(script, "items") == [[1, 2], [5, 4]]
    end
  end

  describe "through an attribute" do
    test "set an item in an entity's list attribute" do
      script =
        run("""
        e = Entity()
        e.items = [1, 2]
        e.items[0] = 5
        """)

      assert script.error == nil
      assert stored_attribute(script, "e", "items") == [5, 2]
    end

    test "does not touch a local variable with the attribute's name" do
      script =
        run("""
        items = [1, 2]
        e = Entity()
        e.items = [3, 4]
        e.items[0] = 5
        """)

      assert script.error == nil
      assert Script.get_variable_value(script, "items") == [1, 2]
      assert stored_attribute(script, "e", "items") == [5, 4]
    end

    test "augmented assignment on an item of an entity's list attribute" do
      script =
        run("""
        e = Entity()
        e.items = [1, 2]
        e.items[1] += 10
        """)

      assert script.error == nil
      assert stored_attribute(script, "e", "items") == [1, 12]
    end

    test "set an item through a chain of attributes" do
      script =
        run("""
        a = Entity()
        b = Entity()
        a.b = b
        b.c = [1, 2]
        a.b.c[0] = 5
        """)

      assert script.error == nil
      assert stored_attribute(script, "b", "c") == [5, 2]
    end

    test "set an attribute after an item reached through an attribute" do
      script =
        run("""
        a = Entity()
        b = Entity()
        a.entities = [b]
        a.entities[0].value = 5
        """)

      assert script.error == nil
      assert stored_attribute(script, "b", "value") == 5
    end
  end
end
