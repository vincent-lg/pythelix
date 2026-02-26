defmodule Pythelix.Scripting.TryExceptTest do
  @moduledoc """
  Tests for try/except/else/finally and raise.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Traceback

  test "basic try/except catches a NameError" do
    script =
      run("""
      try:
        x = unknown_var
      except NameError:
        result = "caught"
      endtry
      """)

    assert script.variables["result"] == "caught"
    assert script.error == nil
  end

  test "try/except with specific exception type" do
    script =
      run("""
      try:
        raise ValueError("bad value")
      except ValueError:
        result = "caught ValueError"
      endtry
      """)

    assert script.variables["result"] == "caught ValueError"
    assert script.error == nil
  end

  test "try/except with bare except catches all" do
    script =
      run("""
      try:
        raise TypeError("wrong type")
      except:
        result = "caught all"
      endtry
      """)

    assert script.variables["result"] == "caught all"
    assert script.error == nil
  end

  test "multiple except clauses, first matches" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except ValueError:
        result = "value error"
      except TypeError:
        result = "type error"
      endtry
      """)

    assert script.variables["result"] == "value error"
  end

  test "multiple except clauses, second matches" do
    script =
      run("""
      try:
        raise TypeError("bad")
      except ValueError:
        result = "value error"
      except TypeError:
        result = "type error"
      endtry
      """)

    assert script.variables["result"] == "type error"
  end

  test "try/else runs when no exception" do
    script =
      run("""
      try:
        x = 1
      except ValueError:
        result = "caught"
      else:
        result = "no error"
      endtry
      """)

    assert script.variables["result"] == "no error"
  end

  test "try/else does not run when exception caught" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except ValueError:
        result = "caught"
      else:
        result = "no error"
      endtry
      """)

    assert script.variables["result"] == "caught"
  end

  test "try/finally always runs after no exception" do
    script =
      run("""
      try:
        x = 1
      except ValueError:
        result = "caught"
      finally:
        cleanup = "done"
      endtry
      """)

    assert script.variables["cleanup"] == "done"
    assert script.variables["result"] == nil
  end

  test "try/finally always runs after caught exception" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except ValueError:
        result = "caught"
      finally:
        cleanup = "done"
      endtry
      """)

    assert script.variables["result"] == "caught"
    assert script.variables["cleanup"] == "done"
  end

  test "try/except/else/finally combined, no exception" do
    script =
      run("""
      try:
        x = 42
      except ValueError:
        result = "caught"
      else:
        result = "else"
      finally:
        cleanup = "done"
      endtry
      """)

    assert script.variables["result"] == "else"
    assert script.variables["cleanup"] == "done"
  end

  test "try/except/else/finally combined, with exception" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except ValueError:
        result = "caught"
      else:
        result = "else"
      finally:
        cleanup = "done"
      endtry
      """)

    assert script.variables["result"] == "caught"
    assert script.variables["cleanup"] == "done"
  end

  test "raise statement creates error" do
    script =
      run("""
      raise ValueError("test error")
      """)

    assert %Traceback{exception: ValueError, message: "test error"} = script.error
  end

  test "raise without message" do
    script =
      run("""
      raise RuntimeError
      """)

    assert %Traceback{exception: RuntimeError} = script.error
  end

  test "unmatched exception propagates" do
    script =
      run("""
      try:
        raise TypeError("wrong")
      except ValueError:
        result = "caught"
      endtry
      """)

    assert %Traceback{exception: TypeError} = script.error
  end

  test "nested try/except blocks" do
    script =
      run("""
      try:
        try:
          raise ValueError("inner")
        except TypeError:
          result = "wrong"
        endtry
      except ValueError:
        result = "outer caught"
      endtry
      """)

    assert script.variables["result"] == "outer caught"
  end

  test "exception hierarchy: LookupError catches KeyError" do
    script =
      run("""
      try:
        raise KeyError("missing key")
      except LookupError:
        result = "caught by parent"
      endtry
      """)

    assert script.variables["result"] == "caught by parent"
  end

  test "exception hierarchy: Exception catches all standard exceptions" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except Exception:
        result = "caught by Exception"
      endtry
      """)

    assert script.variables["result"] == "caught by Exception"
  end

  test "bare except as fallback after specific handler" do
    script =
      run("""
      try:
        raise RuntimeError("unexpected")
      except ValueError:
        result = "value error"
      except:
        result = "fallback"
      endtry
      """)

    assert script.variables["result"] == "fallback"
  end

  test "raise with unknown exception type fails with TypeError" do
    script =
      run("""
      raise Something("not an exception")
      """)

    assert %Traceback{exception: TypeError, message: "exceptions must derive from BaseException"} = script.error
  end

  test "raise unknown exception type caught by bare except" do
    script =
      run("""
      try:
        raise Something("not an exception")
      except:
        result = "caught type error"
      endtry
      """)

    assert script.variables["result"] == "caught type error"
    assert script.error == nil
  end

  test "code after try/except continues normally" do
    script =
      run("""
      try:
        raise ValueError("bad")
      except ValueError:
        x = 1
      endtry
      result = "continued"
      """)

    assert script.variables["result"] == "continued"
    assert script.error == nil
  end
end
