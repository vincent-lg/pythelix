defmodule Pythelix.Scripting.Entity.ParentageTest do
  @moduledoc """
  Module to test the entity API in its parentage (inheritance).
  """

  use Pythelix.DataCase

  alias Pythelix.Record

  describe "creation" do
    test "stored first level, check children" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)

      assert Record.get_children(child) == []
      assert Record.get_children(parent) == [child]
    end

    test "virtual first level, check children" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")

      assert Record.get_children(child) == []
      assert Record.get_children(parent) == [child]
    end

    test "stored second level, check children" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)

      assert Record.get_children(grand_child) == []
      assert Record.get_children(child) == [grand_child]
      assert Record.get_children(parent) == [child]
    end

    test "virtual second level, check children" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")

      assert Record.get_children(grand_child) == []
      assert Record.get_children(child) == [grand_child]
      assert Record.get_children(parent) == [child]
    end

    test "stored second level with branch, check children" do
      {:ok, parent} = Record.create_entity()
      {:ok, child1} = Record.create_entity(parent: parent)
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      {:ok, child2} = Record.create_entity(parent: parent)
      {:ok, grand_child2} = Record.create_entity(parent: child2)

      assert Record.get_children(grand_child1) == []
      assert Record.get_children(grand_child2) == []
      assert Record.get_children(child1) == [grand_child1]
      assert Record.get_children(child2) == [grand_child2]
      assert Enum.sort(Record.get_children(parent)) == Enum.sort([child1, child2])
    end

    test "virtual second level with branch, check children" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)

      assert Record.get_children(grand_child1) == []
      assert Record.get_children(grand_child2) == []
      assert Record.get_children(child1) == [grand_child1]
      assert Record.get_children(child2) == [grand_child2]
      assert Enum.sort(Record.get_children(parent)) == Enum.sort([child1, child2])
    end

    test "stored first level, check ancestors" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)

      assert Record.get_ancestors(child) == [parent]
      assert Record.get_ancestors(parent) == []
    end

    test "virtual first level, check ancestors" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")

      assert Record.get_ancestors(child) == [parent]
      assert Record.get_ancestors(parent) == []
    end

    test "stored second level, check ancestors" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)

      assert Record.get_ancestors(grand_child) == [child, parent]
      assert Record.get_ancestors(child) == [parent]
      assert Record.get_ancestors(parent) == []
    end

    test "virtual second level, check ancestors" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")

      assert Record.get_ancestors(grand_child) == [child, parent]
      assert Record.get_ancestors(child) == [parent]
      assert Record.get_ancestors(parent) == []
    end

    test "stored second level with branch, check ancestors" do
      {:ok, parent} = Record.create_entity()
      {:ok, child1} = Record.create_entity(parent: parent)
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      {:ok, child2} = Record.create_entity(parent: parent)
      {:ok, grand_child2} = Record.create_entity(parent: child2)

      assert Enum.sort(Record.get_ancestors(grand_child1)) == Enum.sort([child1, parent])
      assert Enum.sort(Record.get_ancestors(grand_child2)) == Enum.sort([child2, parent])
      assert Record.get_ancestors(child1) == [parent]
      assert Record.get_ancestors(child2) == [parent]
      assert Record.get_ancestors(parent) == []
    end

    test "virtual second level with branch, check ancestors" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)

      assert Enum.sort(Record.get_ancestors(grand_child1)) == Enum.sort([child1, parent])
      assert Enum.sort(Record.get_ancestors(grand_child2)) == Enum.sort([child2, parent])
      assert Record.get_ancestors(child1) == [parent]
      assert Record.get_ancestors(child2) == [parent]
      assert Record.get_ancestors(parent) == []
    end
  end

  describe "creation with attributes" do
    test "stored first level, check child attributes" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_attribute(parent.id, "test", 3)
      {:ok, child} = Record.create_entity(parent: parent)
      child = Record.set_attribute(child.id, "other", 5)

      assert parent.attributes == %{"test" => 3}
      assert child.attributes == %{"other" => 5, "test" => {:parent, parent.id}}
    end

    test "virtual first level, check child attributes" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_attribute(parent.key, "test", 3)
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      child = Record.set_attribute(child.key, "other", 5)

      assert parent.attributes == %{"test" => 3}
      assert child.attributes == %{"other" => 5, "test" => {:parent, parent.key}}
    end

    test "stored second level, check child attributes" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_attribute(parent.id, "attr1", 1)
      {:ok, child} = Record.create_entity(parent: parent)
      child = Record.set_attribute(child.id, "attr2", 2)
      {:ok, grand_child} = Record.create_entity(parent: child)
      grand_child = Record.set_attribute(grand_child.id, "attr3", 3)

      assert grand_child.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => {:parent, child.id}, "attr3" => 3}
      assert child.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => 2}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "virtual second level, check children" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_attribute(parent.key, "attr1", 1)
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      child = Record.set_attribute(child.key, "attr2", 2)
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")
      grand_child = Record.set_attribute(grand_child.key, "attr3", 3)

      assert grand_child.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => {:parent, child.key}, "attr3" => 3}
      assert child.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => 2}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "stored second level with branch, check child attributes" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_attribute(parent.id, "attr1", 1)
      {:ok, child1} = Record.create_entity(parent: parent)
      child1 = Record.set_attribute(child1.id, "attr2", 2)
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      grand_child1 = Record.set_attribute(grand_child1.id, "attr3", 3)
      {:ok, child2} = Record.create_entity(parent: parent)
      child2 = Record.set_attribute(child2.id, "attr4", 4)
      {:ok, grand_child2} = Record.create_entity(parent: child2)
      grand_child2 = Record.set_attribute(grand_child2.id, "attr5", 5)

      assert grand_child1.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => {:parent, child1.id}, "attr3" => 3}
      assert child1.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => 2}
      assert grand_child2.attributes == %{"attr1" => {:parent, parent.id}, "attr4" => {:parent, child2.id}, "attr5" => 5}
      assert child2.attributes == %{"attr1" => {:parent, parent.id}, "attr4" => 4}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "virtual second level with branch, check child attributes" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_attribute(parent.key, "attr1", 1)
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      child1 = Record.set_attribute(child1.key, "attr2", 2)
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      grand_child1 = Record.set_attribute(grand_child1.key, "attr3", 3)
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      child2 = Record.set_attribute(child2.key, "attr4", 4)
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)
      grand_child2 = Record.set_attribute(grand_child2.key, "attr5", 5)

      assert grand_child1.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => {:parent, child1.key}, "attr3" => 3}
      assert child1.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => 2}
      assert grand_child2.attributes == %{"attr1" => {:parent, parent.key}, "attr4" => {:parent, child2.key}, "attr5" => 5}
      assert child2.attributes == %{"attr1" => {:parent, parent.key}, "attr4" => 4}
      assert parent.attributes == %{"attr1" => 1}
    end
  end

  describe "set attribute and check that they propagate to children" do
    test "stored first level, check child attributes repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      Record.set_attribute(child.id, "other", 5)
      parent = Record.set_attribute(parent.id, "test", 3)
      child = Record.get_entity(child.id)

      assert parent.attributes == %{"test" => 3}
      assert child.attributes == %{"other" => 5, "test" => {:parent, parent.id}}
    end

    test "virtual first level, check child attributes repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      Record.set_attribute(child.key, "other", 5)
      parent = Record.set_attribute(parent.key, "test", 3)
      child = Record.get_entity(child.key)

      assert parent.attributes == %{"test" => 3}
      assert child.attributes == %{"other" => 5, "test" => {:parent, parent.key}}
    end

    test "stored second level, check child attributes repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)
      Record.set_attribute(grand_child.id, "attr3", 3)
      Record.set_attribute(child.id, "attr2", 2)
      parent = Record.set_attribute(parent.id, "attr1", 1)
      child = Record.get_entity(child.id)
      grand_child = Record.get_entity(grand_child.id)

      assert grand_child.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => {:parent, child.id}, "attr3" => 3}
      assert child.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => 2}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "virtual second level, check children repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")
      Record.set_attribute(grand_child.key, "attr3", 3)
      Record.set_attribute(child.key, "attr2", 2)
      parent = Record.set_attribute(parent.key, "attr1", 1)
      child = Record.get_entity(child.key)
      grand_child = Record.get_entity(grand_child.key)

      assert grand_child.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => {:parent, child.key}, "attr3" => 3}
      assert child.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => 2}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "stored second level with branch, check child attributes repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child1} = Record.create_entity(parent: parent)
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      {:ok, child2} = Record.create_entity(parent: parent)
      {:ok, grand_child2} = Record.create_entity(parent: child2)
      Record.set_attribute(grand_child1.id, "attr3", 3)
      Record.set_attribute(grand_child2.id, "attr5", 5)
      Record.set_attribute(child1.id, "attr2", 2)
      Record.set_attribute(child2.id, "attr4", 4)
      parent = Record.set_attribute(parent.id, "attr1", 1)
      child1 = Record.get_entity(child1.id)
      child2 = Record.get_entity(child2.id)
      grand_child1 = Record.get_entity(grand_child1.id)
      grand_child2 = Record.get_entity(grand_child2.id)

      assert grand_child1.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => {:parent, child1.id}, "attr3" => 3}
      assert child1.attributes == %{"attr1" => {:parent, parent.id}, "attr2" => 2}
      assert grand_child2.attributes == %{"attr1" => {:parent, parent.id}, "attr4" => {:parent, child2.id}, "attr5" => 5}
      assert child2.attributes == %{"attr1" => {:parent, parent.id}, "attr4" => 4}
      assert parent.attributes == %{"attr1" => 1}
    end

    test "virtual second level with branch, check child attributes repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)
      Record.set_attribute(grand_child1.key, "attr3", 3)
      Record.set_attribute(child1.key, "attr2", 2)
      Record.set_attribute(grand_child2.key, "attr5", 5)
      Record.set_attribute(child2.key, "attr4", 4)
      parent = Record.set_attribute(parent.key, "attr1", 1)
      grand_child1 = Record.get_entity(grand_child1.key)
      grand_child2 = Record.get_entity(grand_child2.key)
      child1 = Record.get_entity(child1.key)
      child2 = Record.get_entity(child2.key)

      assert grand_child1.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => {:parent, child1.key}, "attr3" => 3}
      assert child1.attributes == %{"attr1" => {:parent, parent.key}, "attr2" => 2}
      assert grand_child2.attributes == %{"attr1" => {:parent, parent.key}, "attr4" => {:parent, child2.key}, "attr5" => 5}
      assert child2.attributes == %{"attr1" => {:parent, parent.key}, "attr4" => 4}
      assert parent.attributes == %{"attr1" => 1}
    end
  end

  describe "creation with methods" do
    test "stored first level, check child methods" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_method(parent.id, "test", "i = 1 + 2")
      {:ok, child} = Record.create_entity(parent: parent)
      child = Record.set_method(child.id, "other", "i = 1 + 2")

      assert parent.methods["test"]
      assert child.methods["other"]
      assert child.methods["test"] == {:parent, parent.id}
    end

    test "virtual first level, check child methods" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_method(parent.key, "test", "i = 1 + 2")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      child = Record.set_method(child.key, "other", "i = 1 + 2")

      assert parent.methods["test"]
      assert child.methods["other"]
      assert child.methods["test"] == {:parent, parent.key}
    end

    test "stored second level, check child methods" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_method(parent.id, "meth1", "i = 1 + 2")
      {:ok, child} = Record.create_entity(parent: parent)
      child = Record.set_method(child.id, "meth2", "i = 1 + 2")
      {:ok, grand_child} = Record.create_entity(parent: child)
      grand_child = Record.set_method(grand_child.id, "meth3", "i = 1 + 2")

      assert grand_child.methods["meth1"] == {:parent, parent.id}
      assert grand_child.methods["meth2"] == {:parent, child.id}
      assert grand_child.methods["meth3"]
      assert child.methods["meth1"] == {:parent, parent.id}
      assert child.methods["meth2"]
      assert parent.methods["meth1"]
    end

    test "virtual second level, check children" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_method(parent.key, "meth1", "i = 1 + 2")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      child = Record.set_method(child.key, "meth2", "i = 1 + 2")
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")
      grand_child = Record.set_method(grand_child.key, "meth3", "i = 1 + 2")

      assert grand_child.methods["meth1"] == {:parent, parent.key}
      assert grand_child.methods["meth2"] == {:parent, child.key}
      assert grand_child.methods["meth3"]
      assert child.methods["meth1"] == {:parent, parent.key}
      assert child.methods["meth2"]
      assert parent.methods["meth1"]
    end

    test "stored second level with branch, check child methods" do
      {:ok, parent} = Record.create_entity()
      parent = Record.set_method(parent.id, "meth1", "i = 1 + 2")
      {:ok, child1} = Record.create_entity(parent: parent)
      child1 = Record.set_method(child1.id, "meth2", "i = 1 + 2")
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      grand_child1 = Record.set_method(grand_child1.id, "meth3", "i = 1 + 2")
      {:ok, child2} = Record.create_entity(parent: parent)
      child2 = Record.set_method(child2.id, "meth4", "i = 1 + 2")
      {:ok, grand_child2} = Record.create_entity(parent: child2)
      grand_child2 = Record.set_method(grand_child2.id, "meth5", "i = 1 + 2")

      assert grand_child1.methods["meth1"] == {:parent, parent.id}
      assert grand_child1.methods["meth2"] == {:parent, child1.id}
      assert grand_child1.methods["meth3"]
      assert child1.methods["meth1"] == {:parent, parent.id}
      assert child1.methods["meth2"]
      assert grand_child2.methods["meth1"] == {:parent, parent.id}
      assert grand_child2.methods["meth4"] == {:parent, child2.id}
      assert grand_child2.methods["meth5"]
      assert child2.methods["meth1"] == {:parent, parent.id}
      assert child2.methods["meth4"]
      assert parent.methods["meth1"]
    end

    test "virtual second level with branch, check child methods" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      parent = Record.set_method(parent.key, "meth1", "i = 1 + 2")
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      child1 = Record.set_method(child1.key, "meth2", "i = 1 + 2")
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      grand_child1 = Record.set_method(grand_child1.key, "meth3", "i = 1 + 2")
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      child2 = Record.set_method(child2.key, "meth4", "i = 1 + 2")
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)
      grand_child2 = Record.set_method(grand_child2.key, "meth5", "i = 1 + 2")

      assert grand_child1.methods["meth1"] == {:parent, parent.key}
      assert grand_child1.methods["meth2"] == {:parent, child1.key}
      assert grand_child1.methods["meth3"]
      assert child1.methods["meth1"] == {:parent, parent.key}
      assert child1.methods["meth2"]
      assert grand_child2.methods["meth1"] == {:parent, parent.key}
      assert grand_child2.methods["meth4"] == {:parent, child2.key}
      assert grand_child2.methods["meth5"]
      assert child2.methods["meth1"] == {:parent, parent.key}
      assert child2.methods["meth4"]
      assert parent.methods["meth1"]
    end
  end

  describe "set methods and check that they propagate to children" do
    test "stored first level, check child methods repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      Record.set_method(child.id, "other", "i = 1 + 2")
      parent = Record.set_method(parent.id, "test", "i = 1 + 2")
      child = Record.get_entity(child.id)

      assert parent.methods["test"]
      assert child.methods["other"]
      assert child.methods["test"] == {:parent, parent.id}
    end

    test "virtual first level, check child methods repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      Record.set_method(child.key, "other", "i = 1 + 2")
      parent = Record.set_method(parent.key, "test", "i = 1 + 2")
      child = Record.get_entity(child.key)

      assert parent.methods["test"]
      assert child.methods["other"]
      assert child.methods["test"] == {:parent, parent.key}
    end

    test "stored second level, check child methods repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)
      Record.set_method(grand_child.id, "meth3", "i = 1 + 2")
      Record.set_method(child.id, "meth2", "i = 1 + 2")
      parent = Record.set_method(parent.id, "meth1", "i = 1 + 2")
      child = Record.get_entity(child.id)
      grand_child = Record.get_entity(grand_child.id)

      assert grand_child.methods["meth1"] == {:parent, parent.id}
      assert grand_child.methods["meth2"] == {:parent, child.id}
      assert grand_child.methods["meth3"]
      assert child.methods["meth1"] == {:parent, parent.id}
      assert child.methods["meth2"]
      assert parent.methods["meth1"]
    end

    test "virtual second level, check children repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child} = Record.create_entity(virtual: true, parent: parent, key: "child")
      {:ok, grand_child} = Record.create_entity(virtual: true, parent: child, key: "grand_child")
      Record.set_method(grand_child.key, "meth3", "i = 1 + 2")
      Record.set_method(child.key, "meth2", "i = 1 + 2")
      parent = Record.set_method(parent.key, "meth1", "i = 1 + 2")
      child = Record.get_entity(child.key)
      grand_child = Record.get_entity(grand_child.key)

      assert grand_child.methods["meth1"] == {:parent, parent.key}
      assert grand_child.methods["meth2"] == {:parent, child.key}
      assert grand_child.methods["meth3"]
      assert child.methods["meth1"] == {:parent, parent.key}
      assert child.methods["meth2"]
      assert parent.methods["meth1"]
    end

    test "stored second level with branch, check child methods repercuted" do
      {:ok, parent} = Record.create_entity()
      {:ok, child1} = Record.create_entity(parent: parent)
      {:ok, grand_child1} = Record.create_entity(parent: child1)
      {:ok, child2} = Record.create_entity(parent: parent)
      {:ok, grand_child2} = Record.create_entity(parent: child2)
      Record.set_method(grand_child1.id, "meth3", "i = 1 + 2")
      Record.set_method(grand_child2.id, "meth5", "i = 1 + 2")
      Record.set_method(child1.id, "meth2", "i = 1 + 2")
      Record.set_method(child2.id, "meth4", "i = 1 + 2")
      parent = Record.set_method(parent.id, "meth1", "i = 1 + 2")
      child1 = Record.get_entity(child1.id)
      child2 = Record.get_entity(child2.id)
      grand_child1 = Record.get_entity(grand_child1.id)
      grand_child2 = Record.get_entity(grand_child2.id)

      assert grand_child1.methods["meth1"] == {:parent, parent.id}
      assert grand_child1.methods["meth2"] == {:parent, child1.id}
      assert grand_child1.methods["meth3"]
      assert child1.methods["meth1"] == {:parent, parent.id}
      assert child1.methods["meth2"]
      assert grand_child2.methods["meth1"] == {:parent, parent.id}
      assert grand_child2.methods["meth4"] == {:parent, child2.id}
      assert grand_child2.methods["meth5"]
      assert child2.methods["meth1"] == {:parent, parent.id}
      assert child2.methods["meth4"]
      assert parent.methods["meth1"]
    end

    test "virtual second level with branch, check child methods repercuted" do
      {:ok, parent} = Record.create_entity(virtual: true, key: "parent")
      {:ok, child1} = Record.create_entity(virtual: true, key: "child1", parent: parent)
      {:ok, grand_child1} = Record.create_entity(virtual: true, key: "grand_child1", parent: child1)
      {:ok, child2} = Record.create_entity(virtual: true, key: "child2", parent: parent)
      {:ok, grand_child2} = Record.create_entity(virtual: true, key: "grand_child2", parent: child2)
      Record.set_method(grand_child1.key, "meth3", "i = 1 + 2")
      Record.set_method(child1.key, "meth2", "i = 1 + 2")
      Record.set_method(grand_child2.key, "meth5", "i = 1 + 2")
      Record.set_method(child2.key, "meth4", "i = 1 + 2")
      parent = Record.set_method(parent.key, "meth1", "i = 1 + 2")
      grand_child1 = Record.get_entity(grand_child1.key)
      grand_child2 = Record.get_entity(grand_child2.key)
      child1 = Record.get_entity(child1.key)
      child2 = Record.get_entity(child2.key)

      assert grand_child1.methods["meth1"] == {:parent, parent.key}
      assert grand_child1.methods["meth2"] == {:parent, child1.key}
      assert grand_child1.methods["meth3"]
      assert child1.methods["meth1"] == {:parent, parent.key}
      assert child1.methods["meth2"]
      assert grand_child2.methods["meth1"] == {:parent, parent.key}
      assert grand_child2.methods["meth4"] == {:parent, child2.key}
      assert grand_child2.methods["meth5"]
      assert child2.methods["meth1"] == {:parent, parent.key}
      assert child2.methods["meth4"]
      assert parent.methods["meth1"]
    end
  end

  describe "change parentage" do
    test "cyclical parentage should be forbidden, put a parent in a child" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)

      assert match?({:error, _}, Record.change_parent(parent, child))
      assert Record.get_children(parent) == [child]
      assert Record.get_ancestors(parent) == []
      assert Record.get_children(child) == []
      assert Record.get_ancestors(child) == [parent]
    end

    test "cyclical parentage should be forbidden, put a parent in a grand child" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)

      assert match?({:error, _}, Record.change_parent(parent, grand_child))
      assert Record.get_children(parent) == [child]
      assert Record.get_ancestors(parent) == []
      assert Record.get_children(child) == [grand_child]
      assert Record.get_ancestors(child) == [parent]
      assert Record.get_children(grand_child) == []
      assert Record.get_ancestors(grand_child) == [child, parent]
    end

    test "indirect cycle: make grandchild the parent of root" do
      {:ok, grandparent} = Record.create_entity()
      {:ok, parent} = Record.create_entity(parent: grandparent)
      {:ok, child} = Record.create_entity(parent: parent)

      # Try to set grandparent's parent to child — should be rejected
      assert match?({:error, _}, Record.change_parent(grandparent, child))

      # Structure remains intact
      assert Record.get_children(grandparent) == [parent]
      assert Record.get_children(parent) == [child]
      assert Record.get_ancestors(child) == [parent, grandparent]
      assert Record.get_ancestors(grandparent) == []
    end

    test "non-cyclical move should succeed" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity()
      {:ok, c} = Record.create_entity(parent: a)

      # Move c from a → b
      c = Record.change_parent(c, b)
      assert !match?({:error, _}, c)

      assert Record.get_children(a) == []
      assert Record.get_children(b) == [c]
      assert Record.get_ancestors(c) == [b]
    end

    test "a child can change parent without ancestry link" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, single} = Record.create_entity()

      child = Record.change_parent(child, single)

      assert Record.get_children(parent) == []
      assert Record.get_ancestors(parent) == []
      assert Record.get_children(child) == []
      assert Record.get_ancestors(child) == [single]
      assert Record.get_children(single) == [child]
      assert Record.get_ancestors(single) == []
    end

    test "check that attributes are properly propagated when the parent changes" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, single} = Record.create_entity()
      Record.set_attribute(parent.id, "a", 1)
      child = Record.set_attribute(child.id, "b", 2)
      single = Record.set_attribute(single.id, "c", 3)

      child = Record.change_parent(child, single)

      assert child.attributes == %{"b" => 2, "c" => {:parent, single.id}}
    end

    test "check that attributes are properly propagated when the parent changes on a second level" do
      {:ok, parent} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: parent)
      {:ok, grand_child} = Record.create_entity(parent: child)
      {:ok, single} = Record.create_entity()
      Record.set_attribute(parent.id, "a", 1)
      child = Record.set_attribute(child.id, "b", 2)
      Record.set_attribute(grand_child.id, "c", 3)
      single = Record.set_attribute(single.id, "d", 4)

      child = Record.change_parent(child, single)

      assert child.attributes == %{"b" => 2, "d" => {:parent, single.id}}
    end

    test "check that attributes are properly propagated when the parent changes on a second level, reversed" do
      {:ok, parent} = Record.create_entity()
      {:ok, single} = Record.create_entity()
      {:ok, child} = Record.create_entity(parent: single)
      {:ok, grand_child} = Record.create_entity(parent: parent)
      parent = Record.set_attribute(parent.id, "a", 1)
      child = Record.set_attribute(child.id, "b", 2)
      grand_child = Record.set_attribute(grand_child.id, "c", 3)
      Record.set_attribute(single.id, "d", 4)

      child = Record.change_parent(child, grand_child)

      assert child.attributes == %{"a" => {:parent, parent.id}, "b" => 2, "c" => {:parent, grand_child.id}}
    end
  end
end
