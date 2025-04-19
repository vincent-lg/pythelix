defmodule Pythelix.Scripting.EntityTest do
  @moduledoc """
  Module to test the entity API.
  """

  use Pythelix.ScriptingCase

  describe "creation" do
    test "an empty entity" do
      script =
        run("""
        ent = Entity()
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert entity.attributes == %{}
      assert entity.methods == %{}
    end

    test "an empty entity, checking its ID attribute" do
      script =
        run("""
        ent = Entity()
        id = ent.id
        """)

      entity = Script.get_variable_value(script, "ent")
      assert entity.id > 0
      assert entity.attributes == %{}
      assert entity.methods == %{}

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert entity.attributes == %{}
      assert entity.methods == %{}
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
      assert map_size(entity.attributes) == 1
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == 5

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == 5
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
      assert map_size(entity.attributes) == 1
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == "ok"

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == "ok"
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
      assert map_size(entity.attributes) == 1
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == 6

      id = Script.get_variable_value(script, "id")
      entity = Pythelix.Record.get_entity(id)
      assert entity.id == id
      assert entity.methods == %{}
      assert Map.get(entity.attributes, "value") == 6
    end
  end
end
