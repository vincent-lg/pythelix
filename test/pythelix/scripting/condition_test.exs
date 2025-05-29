defmodule Pythelix.Scripting.ConditionTest do
  @moduledoc """
  Module to test that conditions are properly created.
  """

  use Pythelix.ScriptingCase

  test "test a True, simple comparison" do
    script =
      run("""
      if 1 < 2:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables == %{"value" => "yes"}
  end

  test "test a False, simple comparison" do
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

  test "test a True, scale comparison" do
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

  test "test a False, scale comparison" do
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

  test "a True, and comparison" do
    script =
      run("""
      âge = 20
      citizen = True
      if âge >= 18 and citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "a True, or comparison" do
    script =
      run("""
      âge = 15
      citizen = True
      if âge >= 18 or citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "a False, and comparison" do
    script =
      run("""
      âge = 20
      citizen = False
      if âge >= 18 and citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "a False, or comparison" do
    script =
      run("""
      âge = 15
      citizen = False
      if âge >= 18 or citizen:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end
end
