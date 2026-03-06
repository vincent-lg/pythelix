defmodule Pythelix.Scripting.AttrFunctionsTest do
  @moduledoc """
  Module to test getattr, setattr, hasattr and delattr built-in functions.
  """

  use Pythelix.ScriptingCase
  alias Pythelix.Record

  describe "getattr" do
    test "getattr on an entity attribute" do
      Record.create_entity(key: "getattr_test")
      Record.set_attribute("getattr_test", "health", 100)

      script =
        run("""
        ent = !getattr_test!
        val = getattr(ent, "health")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == 100
    end

    test "getattr is equivalent to dot access" do
      Record.create_entity(key: "getattr_dot")
      Record.set_attribute("getattr_dot", "name", "hero")

      script =
        run("""
        ent = !getattr_dot!
        val1 = ent.name
        val2 = getattr(ent, "name")
        """)

      assert script.error == nil
      val1 = Script.get_variable_value(script, "val1")
      val2 = Script.get_variable_value(script, "val2")
      assert val1 == val2
    end

    test "getattr with default value when attribute missing" do
      Record.create_entity(key: "getattr_default")

      script =
        run("""
        ent = !getattr_default!
        val = getattr(ent, "missing", "fallback")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == "fallback"
    end

    test "getattr without default returns none for missing attribute" do
      Record.create_entity(key: "getattr_none")

      script =
        run("""
        ent = !getattr_none!
        val = getattr(ent, "missing")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == :none
    end

    test "getattr with f-string attribute name" do
      Record.create_entity(key: "getattr_fstring")
      Record.set_attribute("getattr_fstring", "score", 42)

      script =
        run("""
        ent = !getattr_fstring!
        attr = "score"
        val = getattr(ent, f"{attr}")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == 42
    end

    test "getattr on special attribute id" do
      Record.create_entity(key: "getattr_id")

      script =
        run("""
        ent = !getattr_id!
        val = getattr(ent, "id")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert is_integer(value)
    end
  end

  describe "setattr" do
    test "setattr on an entity" do
      Record.create_entity(key: "setattr_test")

      script =
        run("""
        ent = !setattr_test!
        setattr(ent, "power", 50)
        """)

      assert script.error == nil
      entity = Record.get_entity("setattr_test")
      attributes = Record.get_attributes(entity)
      assert Map.get(attributes, "power") == 50
    end

    test "setattr is equivalent to dot assignment" do
      Record.create_entity(key: "setattr_dot")

      script =
        run("""
        ent = !setattr_dot!
        setattr(ent, "x", 10)
        """)

      assert script.error == nil
      entity = Record.get_entity("setattr_dot")
      attributes = Record.get_attributes(entity)
      assert Map.get(attributes, "x") == 10
    end

    test "setattr with f-string attribute name" do
      Record.create_entity(key: "setattr_fstring")

      script =
        run("""
        ent = !setattr_fstring!
        attr = "level"
        setattr(ent, f"{attr}", 5)
        """)

      assert script.error == nil
      entity = Record.get_entity("setattr_fstring")
      attributes = Record.get_attributes(entity)
      assert Map.get(attributes, "level") == 5
    end

    test "setattr on protected attribute raises error" do
      Record.create_entity(key: "setattr_protected")

      script =
        run("""
        ent = !setattr_protected!
        setattr(ent, "id", 999)
        """)

      assert script.error != nil
    end
  end

  describe "hasattr" do
    test "hasattr returns true for existing attribute" do
      Record.create_entity(key: "hasattr_true")
      Record.set_attribute("hasattr_true", "name", "test")

      script =
        run("""
        ent = !hasattr_true!
        val = hasattr(ent, "name")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == true
    end

    test "hasattr returns false for missing attribute" do
      Record.create_entity(key: "hasattr_false")

      script =
        run("""
        ent = !hasattr_false!
        val = hasattr(ent, "nonexistent")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == false
    end

    test "hasattr returns true for special attributes" do
      Record.create_entity(key: "hasattr_special")

      script =
        run("""
        ent = !hasattr_special!
        val = hasattr(ent, "id")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == true
    end

    test "hasattr with f-string attribute name" do
      Record.create_entity(key: "hasattr_fstring")
      Record.set_attribute("hasattr_fstring", "hp", 100)

      script =
        run("""
        ent = !hasattr_fstring!
        attr = "hp"
        val = hasattr(ent, f"{attr}")
        """)

      assert script.error == nil
      value = Script.get_variable_value(script, "val")
      assert value == true
    end
  end

  describe "delattr" do
    test "delattr removes an entity attribute" do
      Record.create_entity(key: "delattr_test")
      Record.set_attribute("delattr_test", "temp", 42)

      script =
        run("""
        ent = !delattr_test!
        delattr(ent, "temp")
        """)

      assert script.error == nil
      entity = Record.get_entity("delattr_test")
      attributes = Record.get_attributes(entity)
      refute Map.has_key?(attributes, "temp")
    end

    test "delattr on missing attribute raises error" do
      Record.create_entity(key: "delattr_missing")

      script =
        run("""
        ent = !delattr_missing!
        delattr(ent, "no_such")
        """)

      assert script.error != nil
    end

    test "delattr on protected attribute raises error" do
      Record.create_entity(key: "delattr_protected")

      script =
        run("""
        ent = !delattr_protected!
        delattr(ent, "id")
        """)

      assert script.error != nil
    end

    test "delattr with f-string attribute name" do
      Record.create_entity(key: "delattr_fstring")
      Record.set_attribute("delattr_fstring", "data", "value")

      script =
        run("""
        ent = !delattr_fstring!
        attr = "data"
        delattr(ent, f"{attr}")
        """)

      assert script.error == nil
      entity = Record.get_entity("delattr_fstring")
      attributes = Record.get_attributes(entity)
      refute Map.has_key?(attributes, "data")
    end
  end
end
