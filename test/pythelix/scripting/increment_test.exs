defmodule Pythelix.Scripting.IncrementTest do
  @moduledoc """
  Module to test that variable increments (+=, -=, ...) are correctly handled.
  """

  use Pythelix.ScriptingCase

  test "add to a single number" do
    script =
      run("""
      value = 5
      value += 2
      """)

    assert script.variables == %{"value" => 7}
  end

  test "remove from a single number" do
    script =
      run("""
      value = 5
      value -= 2
      """)

    assert script.variables == %{"value" => 3}
  end

  test "mul to a single number" do
    script =
      run("""
      value = 5
      value *= 2
      """)

    assert script.variables == %{"value" => 10}
  end

  test "div to a single number" do
    script =
      run("""
      value = 8
      value /= 2
      """)

    assert script.variables == %{"value" => 4.0}
  end

  test "add an operation" do
    script =
      run("""
      value = 5
      value += (1 + 1) * 3
      """)

    assert script.variables == %{"value" => 11}
  end

  test "sub an operation" do
    script =
      run("""
      value = 5
      value -= (1 + 1) * 3
      """)

    assert script.variables == %{"value" => -1}
  end

  test "mul an operation" do
    script =
      run("""
      value = -5
      value *= (1 + 1) * 3
      """)

    assert script.variables == %{"value" => -30}
  end

  test "div an operation" do
    script =
      run("""
      value = 36
      value /= (1 + 1) * 3
      """)

    assert script.variables == %{"value" => 6}
  end
end
