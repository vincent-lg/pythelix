defmodule Pythelix.Scripting.IntegrationTest do
  use Pythelix.ScriptingCase

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Task.Persistent, as: Task

  setup do
    # Initialize systems needed for integration tests
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()
    Task.init()
    :ok
  end

  describe "script parent and step functionality" do
    test "script can be created with parent and step information" do
      # Create parent script
      parent_script = %Script{
        id: "parent_script",
        bytecode: [],
        variables: %{"parent_var" => "parent_value"}
      }

      # Create child script with parent and step
      child_script = %Script{id: "child_script", bytecode: []}
      |> Script.set_parent(parent_script)
      |> Script.set_step(TestModule, :test_callback, [:arg1, :arg2])

      # Verify parent is set correctly
      assert Script.get_parent(child_script) == parent_script
      assert Script.get_parent(child_script).variables["parent_var"] == "parent_value"

      # Verify step is set correctly
      assert Script.get_step(child_script) == {TestModule, :test_callback, [:arg1, :arg2]}
    end

    test "script serialization preserves parent and step information" do
      # Create a complex script hierarchy
      grandparent = %Script{id: "grandparent", bytecode: [], variables: %{"level" => "grand"}}
      parent = %Script{id: "parent", bytecode: [], parent: grandparent, variables: %{"level" => "parent"}}
      child = %Script{
        id: "child",
        bytecode: [],
        parent: parent,
        step: {TestModule, :callback, [:data]},
        variables: %{"level" => "child"}
      }

      # Serialize and deserialize
      binary = :erlang.term_to_binary(child)
      restored_child = :erlang.binary_to_term(binary)

      # Verify all information is preserved
      assert restored_child.id == "child"
      assert restored_child.variables["level"] == "child"
      assert restored_child.step == {TestModule, :callback, [:data]}

      # Verify parent hierarchy is preserved
      assert restored_child.parent.id == "parent"
      assert restored_child.parent.variables["level"] == "parent"
      assert restored_child.parent.parent.id == "grandparent"
      assert restored_child.parent.parent.variables["level"] == "grand"
    end

    test "step execution works with MFA format" do
      # Create script with step
      script = %Script{
        id: "test_script",
        bytecode: [],
        step: {__MODULE__, :test_step_handler, [:context_data]}
      }

      # Execute step
      result = Script.execute_step(script, :ok)

      # Verify step was called with correct arguments
      assert result == {:step_executed, :ok, script, :context_data}
    end
  end

  describe "script variable inheritance" do
    test "child script can access parent context through reference" do
      # Create parent with variables
      parent = %Script{
        id: "parent",
        bytecode: [],
        variables: %{
          "shared_data" => %{count: 1, name: "test"},
          "parent_only" => "secret"
        }
      }

      # Create child that references parent
      child = %Script{
        id: "child",
        bytecode: [],
        parent: parent,
        variables: %{"child_data" => "child_value"}
      }

      # Child can access its own variables
      assert child.variables["child_data"] == "child_value"

      # Child can access parent variables through parent reference
      assert child.parent.variables["shared_data"][:count] == 1
      assert child.parent.variables["parent_only"] == "secret"
    end

    test "nested script hierarchy maintains full context chain" do
      # Create a 3-level hierarchy
      root = %Script{
        id: "root",
        bytecode: [],
        variables: %{"root_config" => %{timeout: 30}}
      }

      middle = %Script{
        id: "middle",
        bytecode: [],
        parent: root,
        variables: %{"middle_state" => "processing"}
      }

      leaf = %Script{
        id: "leaf",
        bytecode: [],
        parent: middle,
        variables: %{"leaf_result" => "completed"}
      }

      # Leaf can traverse up to root through parent chain
      assert leaf.variables["leaf_result"] == "completed"
      assert leaf.parent.variables["middle_state"] == "processing"
      assert leaf.parent.parent.variables["root_config"][:timeout] == 30
    end
  end

  # Helper function for step testing
  def test_step_handler(status, script, context_data) do
    {:step_executed, status, script, context_data}
  end
end
