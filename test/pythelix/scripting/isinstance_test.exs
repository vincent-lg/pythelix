defmodule Pythelix.Scripting.IsinstanceTest do
  @moduledoc """
  Module to test the isinstance built-in function.
  """

  use Pythelix.ScriptingCase
  alias Pythelix.Record

  describe "isinstance with builtin types" do
    test "isinstance(string, str) is true" do
      assert expr_ok(~s[isinstance("hello", str)]) == true
    end

    test "isinstance(int, str) is false" do
      assert expr_ok("isinstance(42, str)") == false
    end

    test "isinstance(int_value, int) is true" do
      assert expr_ok("isinstance(42, int)") == true
    end

    test "isinstance(string, int) is false" do
      assert expr_ok(~s[isinstance("hello", int)]) == false
    end

    test "isinstance(float_value, float) is true" do
      assert expr_ok("isinstance(3.14, float)") == true
    end

    test "isinstance(int_value, float) is false" do
      assert expr_ok("isinstance(42, float)") == false
    end

    test "isinstance(True, bool) is true" do
      assert expr_ok("isinstance(True, bool)") == true
    end

    test "isinstance(False, bool) is true" do
      assert expr_ok("isinstance(False, bool)") == true
    end

    test "isinstance(1, bool) is false" do
      assert expr_ok("isinstance(1, bool)") == false
    end

    test "isinstance(list, list) is true" do
      assert expr_ok("isinstance([1, 2], list)") == true
    end

    test "isinstance(string, list) is false" do
      assert expr_ok(~s[isinstance("hello", list)]) == false
    end

    test "isinstance(dict, dict) is true" do
      assert expr_ok(~s[isinstance({"a": 1}, dict)]) == true
    end

    test "isinstance(list, dict) is false" do
      assert expr_ok("isinstance([1], dict)") == false
    end

    test "isinstance(set, set) is true" do
      script =
        run_ok("""
        s = set([1, 2, 3])
        result = isinstance(s, set)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(tuple, tuple) is true" do
      script =
        run_ok("""
        t = tuple([1, 2])
        result = isinstance(t, tuple)
        """)

      assert script.variables["result"] == true
    end
  end

  describe "isinstance with Entity builtin" do
    test "isinstance(entity, Entity) is true" do
      Record.create_entity(key: "isinstance_ent1")

      script =
        run_ok("""
        ent = !isinstance_ent1!
        result = isinstance(ent, Entity)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(string, Entity) is false" do
      assert expr_ok(~s[isinstance("hello", Entity)]) == false
    end

    test "isinstance(stackable, stackable) is true" do
      Record.create_entity(key: "isinstance_stack_ent")
      Record.set_attribute("isinstance_stack_ent", "stackable", true)

      script =
        run_ok("""
        s = stackable(!isinstance_stack_ent!, 5)
        result = isinstance(s, stackable)
        """)

      assert script.variables["result"] == true
    end
  end

  describe "isinstance with entity ancestry" do
    test "isinstance(child, parent) is true" do
      {:ok, parent} = Record.create_entity(key: "isinstance_parent")
      Record.create_entity(key: "isinstance_child", parent: parent)

      script =
        run_ok("""
        child = !isinstance_child!
        parent = !isinstance_parent!
        result = isinstance(child, parent)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(entity, itself) is true" do
      Record.create_entity(key: "isinstance_self")

      script =
        run_ok("""
        ent = !isinstance_self!
        result = isinstance(ent, ent)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(parent, child) is false" do
      {:ok, parent} = Record.create_entity(key: "isinstance_p2")
      Record.create_entity(key: "isinstance_c2", parent: parent)

      script =
        run_ok("""
        child = !isinstance_c2!
        parent = !isinstance_p2!
        result = isinstance(parent, child)
        """)

      assert script.variables["result"] == false
    end

    test "isinstance(grandchild, grandparent) is true" do
      {:ok, gp} = Record.create_entity(key: "isinstance_gp")
      {:ok, p} = Record.create_entity(key: "isinstance_mid", parent: gp)
      Record.create_entity(key: "isinstance_gc", parent: p)

      script =
        run_ok("""
        gc = !isinstance_gc!
        gp = !isinstance_gp!
        result = isinstance(gc, gp)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(unrelated, entity) is false" do
      Record.create_entity(key: "isinstance_unrel1")
      Record.create_entity(key: "isinstance_unrel2")

      script =
        run_ok("""
        a = !isinstance_unrel1!
        b = !isinstance_unrel2!
        result = isinstance(a, b)
        """)

      assert script.variables["result"] == false
    end
  end

  describe "isinstance with stackable and entity" do
    test "isinstance(stackable, entity) is true when same entity" do
      Record.create_entity(key: "isinstance_se")
      Record.set_attribute("isinstance_se", "stackable", true)

      script =
        run_ok("""
        s = stackable(!isinstance_se!, 3)
        ent = !isinstance_se!
        result = isinstance(s, ent)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(stackable, parent) is true when entity has parent" do
      {:ok, parent} = Record.create_entity(key: "isinstance_sp")
      Record.create_entity(key: "isinstance_sc", parent: parent)
      Record.set_attribute("isinstance_sc", "stackable", true)

      script =
        run_ok("""
        s = stackable(!isinstance_sc!, 2)
        parent = !isinstance_sp!
        result = isinstance(s, parent)
        """)

      assert script.variables["result"] == true
    end
  end

  describe "isinstance with sub-entity" do
    test "isinstance(sub_entity, EntityName) is true" do
      Record.create_entity(key: "IsinstBase")
      Record.set_method("IsinstBase", "__init__", :free, "")

      script =
        run_ok("""
        sub = IsinstBase()
        result = isinstance(sub, IsinstBase)
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(sub_entity, ParentName) is true with ancestry" do
      {:ok, parent} = Record.create_entity(key: "IsinstSubP")
      Record.create_entity(key: "IsinstSubC", parent: parent)
      Record.set_method("IsinstSubC", "__init__", :free, "")

      script =
        run_ok("""
        sub = IsinstSubC()
        result = isinstance(sub, IsinstSubP)
        """)

      assert script.variables["result"] == true
    end
  end

  describe "isinstance with tuple of types" do
    test "isinstance(str, (str, int)) is true" do
      script =
        run_ok("""
        result = isinstance("hello", (str, int))
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(int, (str, int)) is true" do
      script =
        run_ok("""
        result = isinstance(42, (str, int))
        """)

      assert script.variables["result"] == true
    end

    test "isinstance(float, (str, int)) is false" do
      script =
        run_ok("""
        result = isinstance(3.14, (str, int))
        """)

      assert script.variables["result"] == false
    end

    test "isinstance with entity in tuple" do
      Record.create_entity(key: "isinstance_t_ent")

      script =
        run_ok("""
        ent = !isinstance_t_ent!
        result = isinstance(ent, (str, Entity))
        """)

      assert script.variables["result"] == true
    end
  end
end
