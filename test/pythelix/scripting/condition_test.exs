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

  # Truthiness tests (__bool__)

  test "empty string is falsy" do
    script =
      run("""
      if "":
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "non-empty string is truthy" do
    script =
      run("""
      if "hello":
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "zero integer is falsy" do
    script =
      run("""
      if 0:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "non-zero integer is truthy" do
    script =
      run("""
      if 42:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "empty list is falsy" do
    script =
      run("""
      if []:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "non-empty list is truthy" do
    script =
      run("""
      if [1, 2]:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "yes"
  end

  test "None is falsy" do
    script =
      run("""
      if None:
        value = "yes"
      else:
        value = "no"
      endif
      """)

    assert script.variables["value"] == "no"
  end

  test "bool builtin returns correct values" do
    script =
      run("""
      a = bool("")
      b = bool("hello")
      c = bool(0)
      d = bool(1)
      e = bool([])
      f = bool([1])
      g = bool(None)
      h = bool(True)
      i = bool(False)
      """)

    assert script.variables["a"] == false
    assert script.variables["b"] == true
    assert script.variables["c"] == false
    assert script.variables["d"] == true
    assert script.variables["e"] == false
    assert script.variables["f"] == true
    assert script.variables["g"] == false
    assert script.variables["h"] == true
    assert script.variables["i"] == false
  end

  test "not operator with truthiness" do
    script =
      run("""
      a = not ""
      b = not "hello"
      c = not 0
      d = not 1
      e = not []
      f = not None
      """)

    assert script.variables["a"] == true
    assert script.variables["b"] == false
    assert script.variables["c"] == true
    assert script.variables["d"] == false
    assert script.variables["e"] == true
    assert script.variables["f"] == true
  end
end
