defmodule Pythelix.Scripting.Namespace.EntityTest do
  @moduledoc """
  Module to test the entity API.
  """

  use Pythelix.ScriptingCase
  alias Pythelix.Record

  describe "creation" do
    test "an empty entity" do
      script =
        run("""
        ent = Entity()
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert Record.get_attributes(entity) == %{}
      assert Record.get_methods(entity) == %{}
    end

    test "an empty entity, checking its ID attribute" do
      script =
        run("""
        ent = Entity()
        id = ent.id
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert Record.get_attributes(entity) == %{}
      assert Record.get_methods(entity) == %{}

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert Record.get_attributes(entity) == %{}
      assert Record.get_methods(entity) == %{}
    end

    test "create an entity with key and retrieve in the script" do
      {:ok, entity} = Record.create_entity(key: "this")

      script =
        run("""
        ent = !this!
        id = ent.id
        """)

      id = Script.get_variable_value(script, "id")
      assert entity.id == id
    end
  end

  describe "attribute getting" do
    test "get an existing attribute in an existing entity" do
      Record.create_entity(key: "test")
      Record.set_attribute("test", "thing", 35)

      script =
        run("""
        num = !test!.thing
        """)

      number = Script.get_variable_value(script, "num")
      assert number == 35
    end
  end

  describe "attribute setting" do
    test "create entity and set attribute with number" do
      script =
        run("""
        ent = Entity()
        ent.value = 5
        id = ent.id
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert map_size(Record.get_attributes(entity)) == 1
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == 5

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == 5
    end

    test "create entity and set attribute with string" do
      script =
        run("""
        ent = Entity()
        ent.value = "ok"
        id = ent.id
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert map_size(Record.get_attributes(entity)) == 1
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == "ok"

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == "ok"
    end

    test "create entity and set attribute with an operation" do
      script =
        run("""
        ent = Entity()
        ent.value = 2 * 3
        id = ent.id
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert map_size(Record.get_attributes(entity)) == 1
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == 6

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert Record.get_methods(entity) == %{}
      assert Map.get(Record.get_attributes(entity), "value") == 6
    end

    test "create entity and set attribute with a list, then append to it" do
      script =
        run("""
        ent = Entity()
        ent.value = []
        ent.value.append(128)
        """)

      entity = Script.get_variable_value(script, "ent")
      assert Record.get_attribute(entity, "value") == [128]
    end
  end

  describe "parent and inheritance with attribute setting" do
    test "create two entities and set an attribute on one" do
      script =
        run("""
        parent = Entity()
        parent.test = -5
        child = Entity(parent=parent)
        """)

      entity = Script.get_variable_value(script, "child")
      assert Record.get_attribute(entity, "test") == -5
    end
  end
end
