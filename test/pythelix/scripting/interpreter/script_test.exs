defmodule Pythelix.Scripting.Interpreter.ScriptTest do
  use Pythelix.ScriptingCase

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Scripting.Interpreter.Script

  describe "parent and step management" do
    test "sets parent script correctly" do
      parent = %Script{id: "parent", bytecode: []}
      child = %Script{id: "child_script", bytecode: []}

      updated_child = Script.set_parent(child, parent)

      assert updated_child.parent == parent
      assert updated_child.id == child.id
    end

    test "gets parent script correctly" do
      parent = %Script{id: "parent", bytecode: []}
      child = %Script{id: "child_script", bytecode: [], parent: parent}

      assert Script.get_parent(child) == parent
    end

    test "gets nil when no parent exists" do
      child = %Script{id: "child_script", bytecode: []}

      assert Script.get_parent(child) == nil
    end

    test "sets step correctly with args" do
      script = %Script{id: "test_script", bytecode: []}

      updated_script = Script.set_step(script, TestModule, :test_function, [:arg1, :arg2])

      assert updated_script.step == {TestModule, :test_function, [:arg1, :arg2]}
    end

    test "sets step correctly without args" do
      script = %Script{id: "test_script", bytecode: []}

      updated_script = Script.set_step(script, TestModule, :test_function)

      assert updated_script.step == {TestModule, :test_function, []}
    end

    test "gets step correctly" do
      script = %Script{id: "test_script", bytecode: [], step: {TestModule, :test_function, [:arg1]}}

      assert Script.get_step(script) == {TestModule, :test_function, [:arg1]}
    end

    test "gets nil when no step exists" do
      script = %Script{id: "test_script", bytecode: []}

      assert Script.get_step(script) == nil
    end
  end

  describe "step execution" do
    test "executes step successfully" do
      script = %Script{
        id: "test_script_123",
        bytecode: [],
        step: {__MODULE__, :test_step_success, [:extra_arg]}
      }

      result = Script.execute_step(script, :ok)
      assert result == {:success, :ok, script, :extra_arg}
    end

    test "executes step with error status" do
      script = %Script{
        id: "test_script_123",
        bytecode: [],
        step: {__MODULE__, :test_step_error, []}
      }

      result = Script.execute_step(script, :error)
      assert result == {:error_handled, :error, script}
    end

    test "returns :no_step when no step is defined" do
      script = %Script{id: "test_script", bytecode: []}

      result = Script.execute_step(script, :ok)
      assert result == :no_step
    end

    test "handles step execution errors gracefully" do
      script = %Script{
        id: "test_script_123",
        bytecode: [],
        step: {NonExistentModule, :nonexistent_function, []}
      }

      result = Script.execute_step(script, :ok)
      assert match?({:error, _}, result)
    end

    test "logs errors when step execution fails" do
      script = %Script{
        id: "test_script_123",
        bytecode: [],
        step: {__MODULE__, :test_step_raise, []}
      }

      # Capture log output
      import ExUnit.CaptureLog

      log = capture_log(fn ->
        result = Script.execute_step(script, :ok)
        assert match?({:error, _}, result)
      end)

      assert log =~ "Failed to execute step"
      assert log =~ "test_step_raise"
    end
  end

  describe "script serialization compatibility" do
    test "script structure can be serialized and deserialized" do
      parent = %Script{id: "parent", bytecode: [:parent_op]}
      script = %Script{
        id: "test_script_123",
        bytecode: [:some, :opcodes],
        parent: parent,
        step: {TestModule, :test_function, [:arg]},
        variables: %{"test" => "value"},
        cursor: 5,
        pause: 10
      }

      # Serialize and deserialize
      binary = :erlang.term_to_binary(script)
      deserialized = :erlang.binary_to_term(binary)

      # Verify all fields are preserved
      assert deserialized.id == script.id
      assert deserialized.bytecode == script.bytecode
      assert deserialized.parent == script.parent
      assert deserialized.step == script.step
      assert deserialized.variables == script.variables
      assert deserialized.cursor == script.cursor
      assert deserialized.pause == script.pause
    end

    test "nested script hierarchy serializes correctly" do
      grandparent = %Script{id: "grandparent", bytecode: []}
      parent = %Script{id: "parent", bytecode: [], parent: grandparent}
      child = %Script{id: "child", bytecode: [], parent: parent}

      # Serialize and deserialize
      binary = :erlang.term_to_binary(child)
      deserialized = :erlang.binary_to_term(binary)

      # Verify hierarchy is preserved
      assert deserialized.parent.id == "parent"
      assert deserialized.parent.parent.id == "grandparent"
    end
  end

  # Helper functions for step testing
  def test_step_success(status, script, extra_arg) do
    {:success, status, script, extra_arg}
  end

  def test_step_error(status, script) do
    {:error_handled, status, script}
  end

  def test_step_raise(_status, _script) do
    raise "Intentional error for testing"
  end
end
