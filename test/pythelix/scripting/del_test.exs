defmodule Pythelix.Scripting.DelTest do
  @moduledoc """
  Module to test the del keyword.
  """

  use Pythelix.ScriptingCase
  alias Pythelix.Record

  describe "parsing" do
    test "del a single variable" do
      ast = exec_ok("del x")
      assert ast == {:stmt_list, [{:del, ["x"], {1, 0}}]}
    end

    test "del a dotted attribute" do
      ast = exec_ok("del entity.name")
      assert ast == {:stmt_list, [{:del, ["entity", "name"], {1, 0}}]}
    end

    test "del a nested dotted attribute" do
      ast = exec_ok("del entity.sub.attr")
      assert ast == {:stmt_list, [{:del, ["entity", "sub", "attr"], {1, 0}}]}
    end
  end

  describe "del variable" do
    test "del removes a variable from scope" do
      script =
        run("""
        x = 5
        del x
        """)

      assert script.error == nil
      refute Map.has_key?(script.variables, "x")
    end

    test "del on undefined variable raises NameError" do
      script =
        run("""
        del undefined_var
        """)

      assert script.error != nil
    end
  end

  describe "del entity" do
    test "del removes an entity from the database" do
      {:ok, _entity} = Record.create_entity(key: "del_test")
      assert Record.get_entity("del_test") != nil

      script =
        run("""
        ent = !del_test!
        del ent
        """)

      assert script.error == nil
      assert Record.get_entity("del_test") == nil
    end
  end

  describe "del entity attribute" do
    test "del removes an entity attribute" do
      Record.create_entity(key: "del_attr_test")
      Record.set_attribute("del_attr_test", "value", 42)

      script =
        run("""
        ent = !del_attr_test!
        del ent.value
        """)

      assert script.error == nil
      entity = Record.get_entity("del_attr_test")
      attributes = Record.get_attributes(entity)
      refute Map.has_key?(attributes, "value")
    end

    test "del on a non-existing attribute raises AttributeError" do
      Record.create_entity(key: "del_attr_missing")

      script =
        run("""
        ent = !del_attr_missing!
        del ent.no_such_attr
        """)

      assert script.error != nil
    end

    test "del cannot remove protected attributes like id" do
      Record.create_entity(key: "del_attr_id")

      script =
        run("""
        ent = !del_attr_id!
        del ent.id
        """)

      assert script.error != nil
    end
  end

  describe "parsing del item" do
    test "del a list item" do
      ast = exec_ok("del x[0]")
      assert ast == {:stmt_list, [{:del, [[getitem: [{:var, "x"}, 0]]], {1, 0}}]}
    end

    test "del a dict item" do
      ast = exec_ok(~s|del d["key"]|)
      assert ast == {:stmt_list, [{:del, [[getitem: [{:var, "d"}, "key"]]], {1, 0}}]}
    end

    test "del a nested item" do
      ast = exec_ok("del a.b[0]")
      assert ast == {:stmt_list, [{:del, ["a", [getitem: [{:var, "b"}, 0]]], {1, 0}}]}
    end
  end

  describe "del list item" do
    test "del removes an element from a list by index" do
      script =
        run("""
        items = [10, 20, 30]
        del items[1]
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "items")
      assert value == [10, 30]
    end

    test "del removes the first element from a list" do
      script =
        run("""
        items = [1, 2, 3]
        del items[0]
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "items")
      assert value == [2, 3]
    end

    test "del removes the last element from a list with negative index" do
      script =
        run("""
        items = [1, 2, 3]
        del items[-1]
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "items")
      assert value == [1, 2]
    end

    test "del on out-of-range list index raises IndexError" do
      script =
        run("""
        items = [1, 2]
        del items[5]
        """)

      assert script.error != nil
    end
  end

  describe "del dict item" do
    test "del removes a key from a dict" do
      script =
        run("""
        d = {"a": 1, "b": 2, "c": 3}
        del d["b"]
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "d")
      assert value |> Pythelix.Scripting.Object.Dict.get("a") == 1
      assert value |> Pythelix.Scripting.Object.Dict.get("b") == nil
      assert value |> Pythelix.Scripting.Object.Dict.get("c") == 3
    end

    test "del on non-existing dict key raises KeyError" do
      script =
        run("""
        d = {"a": 1}
        del d["missing"]
        """)

      assert script.error != nil
    end
  end
end
