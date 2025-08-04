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

  test "elif where if condition true" do
    script =
      run("""
      score = 95
      if score >= 90:
        grade = "A"
      elif score >= 80:
        grade = "B"
      elif score >= 70:
        grade = "C"
      else:
        grade = "F"
      endif
      """)

    assert script.variables == %{"score" => 95, "grade" => "A"}
  end

  test "elif first condition true" do
    script =
      run("""
      score = 85
      if score >= 90:
        grade = "A"
      elif score >= 80:
        grade = "B"
      elif score >= 70:
        grade = "C"
      else:
        grade = "F"
      endif
      """)

    assert script.variables == %{"score" => 85, "grade" => "B"}
  end

  test "elif second condition true" do
    script =
      run("""
      score = 75
      if score >= 90:
        grade = "A"
      elif score >= 80:
        grade = "B"
      elif score >= 70:
        grade = "C"
      else:
        grade = "F"
      endif
      """)

    assert script.variables == %{"score" => 75, "grade" => "C"}
  end

  test "elif none true, else executed" do
    script =
      run("""
      score = 60
      if score >= 90:
        grade = "A"
      elif score >= 80:
        grade = "B"
      elif score >= 70:
        grade = "C"
      else:
        grade = "F"
      endif
      """)

    assert script.variables == %{"score" => 60, "grade" => "F"}
  end

  test "elif with no else" do
    script =
      run("""
      score = 60
      grade = "default"
      if score >= 90:
        grade = "A"
      elif score >= 80:
        grade = "B"
      elif score >= 70:
        grade = "C"
      endif
      """)

    assert script.variables == %{"score" => 60, "grade" => "default"}
  end

  test "single elif true" do
    script =
      run("""
      age = 16
      if age >= 18:
        status = "adult"
      elif age >= 13:
        status = "teen"
      endif
      """)

    assert script.variables == %{"age" => 16, "status" => "teen"}
  end
end
