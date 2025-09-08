defmodule Pythelix.Task.ScriptTest do
  use Pythelix.DataCase

  alias Pythelix.Game.Hub
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Task.Script

  @moduletag capture_log: true
  @console Test.Pythelix.Adapters.Console
  @cluster Test.Pythelix.Adapters.ClusterCtl

  setup_all do
    # Start the Game Hub for new system
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    {:ok, _console} = @console.start_link()
    {:ok, []}
  end

  describe "enter input, get result" do
    test "a mathematical operation" do
      @console.feed_input("2 + 3")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 4
      assert "5" in output
      assert Enum.count(output, & &1 == ">>> ") == 2
    end

    test "a list, an object with references" do
      @console.feed_input("[1, 2, 3]")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 4
      assert "[1, 2, 3]" in output
      assert Enum.count(output, & &1 == ">>> ") == 2
    end

    test "a syntax error raising a traceback" do
      @console.feed_input("<>")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 4
      assert Enum.count(output, & &1 == ">>> ") == 2
      assert Enum.any?(output, fn line ->
        String.starts_with?(line, "Traceback most recent call last:")
      end)
    end

    test "a name error error raising a traceback" do
      @console.feed_input("unknown_variable")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 4
      assert Enum.count(output, & &1 == ">>> ") == 2
      assert Enum.any?(output, fn line ->
        String.starts_with?(line, "Traceback most recent call last:")
      end)
    end

    test "a valid list expression spread on several lines" do
      @console.feed_input("[1, 2,")
      @console.feed_input("2 + 3]")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 5
      assert "[1, 2, 5]" in output
      assert Enum.count(output, & &1 == "... ") == 1
      assert Enum.count(output, & &1 == ">>> ") == 2
    end

    test "a valid mathematical expression spread on several lines" do
      @console.feed_input("(")
      @console.feed_input("  1 + 4")
      @console.feed_input(")")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 6
      assert "5" in output
      assert Enum.count(output, & &1 == "... ") == 2
      assert Enum.count(output, & &1 == ">>> ") == 2
    end

    test "two instructions with a variable" do
      @console.feed_input("i = 2 * 4")
      @console.feed_input("i + 2")
      Script.run(@console, @cluster)
      output = @console.outputs()
      assert length(output) == 5
      assert "10" in output
      assert Enum.count(output, & &1 == "... ") == 0
      assert Enum.count(output, & &1 == ">>> ") == 3
    end
  end
end
