defmodule Pythelix.Scripting.Format.NestedTest do
  @moduledoc """
  An f-string expression may itself produce an f-string, typically a method
  returning one. It is text like any other, not a struct to crash on.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Format.String, as: FString

  test "an f-string inside an f-string is formatted" do
    script =
      run("""
      inner = f"{1 + 1} apples"
      outer = f"I have {inner}."
      """)

    assert script.error == nil
    assert FString.format(Script.get_variable_value(script, "outer")) == "I have 2 apples."
  end

  test "a nested f-string is formatted for a viewer too" do
    script =
      run("""
      inner = f"{1 + 1} apples"
      outer = f"I have {inner}."
      """)

    assert script.error == nil
    {text, entities} = FString.format_for(Script.get_variable_value(script, "outer"), nil)
    assert text == "I have 2 apples."
    assert entities == MapSet.new()
  end
end
