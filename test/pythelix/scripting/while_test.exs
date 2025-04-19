defmodule Pythelix.Scripting.WhileTest do
  @moduledoc """
  Module to test that while loops are properly created.
  """

  use Pythelix.ScriptingCase

  test "repeat for 10 iterations" do
    script =
      run("""
      i = 0
      times = 2

      while i < 10:
        i = i + 1
        times = times * 2
      done
      """)

    assert script.variables == %{"i" => 10, "times" => 2048}
  end

  test "test a false, simple comparison" do
    script =
      run("""
      if -2 >= 8:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables == %{"value" => "no"}
  end

  test "test a true, scale comparison" do
    script =
      run("""
      if 1 < 2 <= 4:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables == %{"value" => "yes"}
  end

  test "test a false, scale comparison" do
    script =
      run("""
      if 10 >= 5 > 8:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables == %{"value" => "no"}
  end

  test "a true, and comparison" do
    script =
      run("""
      âge = 20
      citizen = true
      if âge >= 18 and citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "a true, or comparison" do
    script =
      run("""
      âge = 15
      citizen = true
      if âge >= 18 or citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "a false, and comparison" do
    script =
      run("""
      âge = 20
      citizen = false
      if âge >= 18 and citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "a false, or comparison" do
    script =
      run("""
      âge = 15
      citizen = false
      if âge >= 18 or citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end
end
