defmodule Pythelix.Scripting.Namespace.SubEntityTest do
  @moduledoc """
  Module to test the sub-entity API.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Record

  setup do
    Pythelix.World.apply(:static)
    %{}
  end

  describe "Controls" do
    test "set an empty control list and cache" do
      script =
        run_ok("""
        ent = Entity()
        ent.c1 = Controls()
        id = ent.id
        """)

      id = Script.get_variable_value(script, "id")

      entity = Record.get_entity(id)
      value = Record.get_attribute(entity, "c1")
      assert value != nil
      controls = Dict.get(value.data, "__controls")
      assert controls == MapSet.new()
    end

    test "set an control list with one entity and cache" do
      script =
        run_ok("""
        ent = Entity()
        ent.c1 = Controls()
        ent.c1.add(ent)
        id = ent.id
        """)

      id = Script.get_variable_value(script, "id")
      entity = Record.get_entity(id)
      value = Record.get_attribute(entity, "c1")
      assert value != nil
      controls = Dict.get(value.data, "__controls")
      assert controls == MapSet.new([id])
    end

    test "set an empty control list and no cache" do
      script =
        run_ok("""
        ent = Entity()
        ent.c1 = Controls()
        id = ent.id
        """)

      id = Script.get_variable_value(script, "id")
      Record.Cache.commit_and_clear()

      entity = Record.get_entity(id)
      value = Record.get_attribute(entity, "c1")
      assert value != nil
      controls = Dict.get(value.data, "__controls")
      assert controls == MapSet.new()
    end

    test "set an control list with one entity and no cache" do
      script =
        run_ok("""
        ent = Entity()
        ent.c1 = Controls()
        ent.c1.add(ent)
        id = ent.id
        """)

      id = Script.get_variable_value(script, "id")
      Record.Cache.commit_and_clear()

      entity = Record.get_entity(id)
      value = Record.get_attribute(entity, "c1")
      assert value != nil
      controls = Dict.get(value.data, "__controls")
      assert controls == MapSet.new([id])
    end
  end
end
