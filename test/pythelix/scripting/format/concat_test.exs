defmodule Pythelix.Scripting.Format.ConcatTest do
  @moduledoc """
  Tests for f-string concatenation, particularly in loops where the same
  variable names take different values on each iteration.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Format.String, as: FString

  describe "f-string concatenation in loops" do
    test "concatenating f-strings in a loop preserves per-iteration values" do
      script =
        run("""
        result = ""
        for i in [1, 2, 3]:
            result += f"{i} "
        done
        """)

      assert script.error == nil
      value = FString.format(Script.get_variable_value(script, "result"))
      assert value == "1 2 3 "
    end

    test "concatenating f-strings with two loop variables" do
      script =
        run("""
        colors = ("blue", "green", "brown")
        result = "Colors:"
        i = 1
        for color in colors:
            result += f"\\n  {i} for {color}"
            i += 1
        done
        """)

      assert script.error == nil
      value = FString.format(Script.get_variable_value(script, "result"))
      assert value == "Colors:\n  1 for blue\n  2 for green\n  3 for brown"
    end

    test "f-string repeat preserves variables" do
      script =
        run("""
        x = 5
        result = f"{x}!" * 3
        """)

      assert script.error == nil
      value = FString.format(Script.get_variable_value(script, "result"))
      assert value == "5!5!5!"
    end
  end
end
