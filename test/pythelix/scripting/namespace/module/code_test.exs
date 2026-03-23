defmodule Pythelix.Scripting.Namespace.Module.CodeTest do
  @moduledoc """
  Tests for the code module: Console REPL.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.{Console, Dict}

  describe "code.Console — creation" do
    test "creates a Console with no variables" do
      script =
        run("""
        result = code.Console()
        """)

      result = Script.get_variable_value(script, "result")
      assert %Console{buffer: nil, variables: variables} = result
      assert variables == %{}
    end

    test "creates a Console with initial variables" do
      script =
        run("""
        result = code.Console({"x": 5, "name": "test"})
        """)

      result = Script.get_variable_value(script, "result")
      assert %Console{variables: variables} = result
      assert variables["x"] == 5
      assert variables["name"] == "test"
    end
  end

  describe "code.Console — push with complete code" do
    test "executes simple expression" do
      script =
        run("""
        console = code.Console()
        result = console.push("1 + 2")
        """)

      result = Script.get_variable_value(script, "result")
      assert %Dict{} = result
      assert Dict.get(result, "status") == "complete"
      assert Dict.get(result, "value") == "3"
      assert Dict.get(result, "error") == :none
    end

    test "executes assignment (no return value)" do
      script =
        run("""
        console = code.Console()
        result = console.push("x = 42")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "complete"
      assert Dict.get(result, "value") == :none
    end

    test "retains variables across pushes" do
      script =
        run("""
        console = code.Console()
        console.push("x = 10")
        result = console.push("x * 3")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "complete"
      assert Dict.get(result, "value") == "30"
    end
  end

  describe "code.Console — push with incomplete code" do
    test "returns need_more for unclosed block" do
      script =
        run("""
        console = code.Console()
        result = console.push("if True:")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "need_more"
    end

    test "accumulates buffer and executes when complete" do
      script =
        run("""
        console = code.Console()
        console.push("if True:")
        result = console.push("endif")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "complete"
    end
  end

  describe "code.Console — push with errors" do
    test "returns error for syntax errors" do
      script =
        run("""
        console = code.Console()
        result = console.push(")")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "error"
      assert Dict.get(result, "error") != :none
    end

    test "returns error for runtime errors" do
      script =
        run("""
        console = code.Console()
        result = console.push("1 / 0")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "error"
      assert Dict.get(result, "error") != :none
    end
  end

  describe "code.Console — initial variables" do
    test "uses initial variables during execution" do
      script =
        run("""
        console = code.Console({"x": 100})
        result = console.push("x + 1")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "complete"
      assert Dict.get(result, "value") == "101"
    end
  end

  describe "code.Console — reset and clear" do
    test "reset clears buffer but keeps variables" do
      script =
        run("""
        console = code.Console()
        console.push("x = 5")
        console.push("if True:")
        console.reset()
        result = console.push("x")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "complete"
      assert Dict.get(result, "value") == "5"
    end

    test "clear resets both buffer and variables" do
      script =
        run("""
        console = code.Console({"x": 5})
        console.clear()
        result = console.push("x")
        """)

      result = Script.get_variable_value(script, "result")
      assert Dict.get(result, "status") == "error"
    end
  end

  describe "code.Console — attributes" do
    test "buffer is None when empty" do
      script =
        run("""
        console = code.Console()
        result = console.buffer
        """)

      result = Script.get_variable_value(script, "result")
      assert result == :none
    end

    test "buffer contains accumulated code" do
      script =
        run("""
        console = code.Console()
        console.push("if True:")
        result = console.buffer
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "if True:"
    end

    test "repr shows summary" do
      script =
        run("""
        console = code.Console({"x": 1})
        result = repr(console)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "<Console (1 vars)>"
    end
  end
end
