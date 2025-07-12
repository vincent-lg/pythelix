defmodule Pythelix.Scripting.Namespace.SetTest do
  @moduledoc """
  Module to test the set API.
  """

  use Pythelix.ScriptingCase

  describe "creation" do
    test "an empty set" do
      set = expr_ok("set()")
      assert MapSet.size(set) == 0
    end

    test "a set with one value" do
      set = expr_ok("{2 + 5}")
      assert set == MapSet.new([7])
    end

    test "a set with two values" do
      set = expr_ok("{-2, 'ok'}")
      assert set == MapSet.new([-2, "ok"])
    end
  end

  describe "__getitem__" do
    test "always fail" do
      traceback = expr_fail("""
      s = set()
      s[8]
      """)
      assert traceback.exception == TypeError
    end
  end

  describe "__setitem__" do
    test "should always fail" do
      traceback = expr_fail("""
      s = set()
      s[8] = 7
      """)
      assert traceback.exception == TypeError
    end
  end

  describe "add" do
    test "add to an empty set" do
      set = expr_ok("""
      s = set()
      s.add(5)
      s
      """)
      assert set == MapSet.new([5])
    end

    test "add to set containing something else" do
      set = expr_ok("""
      s = {8}
      s.add(5)
      s
      """)
      assert set == MapSet.new([8, 5])
    end

    test "add to an set containing this value already" do
      set = expr_ok("""
      s = {5}
      s.add(5)
      s
      """)
      assert set == MapSet.new([5])
    end
  end

  describe "clear" do
    test "clear an empty set" do
      set = expr_ok("""
      s = set()
      s.clear()
      s
      """)
      assert MapSet.size(set) == 0
    end

    test "clear a set with one value" do
      set = expr_ok("""
      s = {2 + 5}
      s.clear()
      s
      """)
      assert MapSet.size(set) == 0
    end

    test "clear a set with two values" do
      set = expr_ok("""
      s = {-2, 'ok'}
      s.clear()
      s
      """)
      assert MapSet.size(set) == 0
    end
  end

  describe "copy" do
    test "an empty set" do
      set = expr_ok("""
      s = set()
      s.copy()
      """)
      assert MapSet.size(set) == 0
    end

    test "a set with one value" do
      set = expr_ok("""
      s = {2 + 5}
      s.copy()
      """)
      assert set == MapSet.new([7])
    end

    test "a set with two values" do
      set = expr_ok("""
      s = {-2, 'ok'}
      s.copy()
      """)
      assert set == MapSet.new([-2, "ok"])
    end
  end

  describe "difference" do
    test "between two sets" do
      script = run("""
      a = {5, 8}
      b = {9, 8, 3}
      a.difference(b)
      """)
      set = Store.get_value(script.last_raw)
      assert set == MapSet.new([5])
      assert Script.get_variable_value(script, "a") == MapSet.new([5, 8])
      assert Script.get_variable_value(script, "b") == MapSet.new([9, 8, 3])
    end
  end

  describe "difference_update" do
    test "between two sets" do
      script = run("""
      a = {5, 8}
      b = {9, 8, 3}
      a.difference_update(b)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([5])
      assert Script.get_variable_value(script, "b") == MapSet.new([9, 8, 3])
    end
  end

  describe "discard" do
    test "value in set" do
      script = run("""
      a = {5, 8}
      a.discard(5)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([8])
    end

    test "value not in set" do
      script = run("""
      a = {5, 8}
      a.discard(9)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([5, 8])
    end
  end

  describe "intersection" do
    test "between two sets" do
      script = run("""
      a = {5, 8}
      b = {9, 8, 3}
      a.intersection(b)
      """)
      assert Store.get_value(script.last_raw) == MapSet.new([8])
      assert Script.get_variable_value(script, "a") == MapSet.new([5, 8])
      assert Script.get_variable_value(script, "b") == MapSet.new([9, 8, 3])
    end
  end

  describe "intersection_update" do
    test "between two sets" do
      script = run("""
      a = {5, 8}
      b = {9, 8, 3}
      a.intersection_update(b)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([8])
      assert Script.get_variable_value(script, "b") == MapSet.new([9, 8, 3])
    end
  end

  describe "isdisjoint" do
    test "two completely disjoint sets" do
      script = run("""
      a = {1, 2}
      b = {3, 4}
      a.isdisjoint(b)
      """)
      assert Store.get_value(script.last_raw) == true
      # originals untouched
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2])
      assert Script.get_variable_value(script, "b") == MapSet.new([3, 4])
    end

    test "not disjoint when they share elements" do
      script = run("""
      a = {1, 2}
      b = {2, 3}
      a.isdisjoint(b)
      """)
      assert Store.get_value(script.last_raw) == false
    end

    test "empty set is disjoint with anything" do
      script = run("""
      a = set()
      b = {7}
      a.isdisjoint(b)
      """)
      assert Store.get_value(script.last_raw) == true
    end
  end

  describe "issubset" do
    test "proper subset" do
      script = run("""
      a = {1, 2}
      b = {1, 2, 3}
      a.issubset(b)
      """)
      assert Store.get_value(script.last_raw) == true
      # originals still intact
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2])
      assert Script.get_variable_value(script, "b") == MapSet.new([1, 2, 3])
    end

    test "equal sets count as subset" do
      script = run("""
      a = {1, 2}
      b = {1, 2}
      a.issubset(b)
      """)
      assert Store.get_value(script.last_raw) == true
    end

    test "not a subset when extra elements" do
      script = run("""
      a = {1, 4}
      b = {1, 2, 3}
      a.issubset(b)
      """)
      assert Store.get_value(script.last_raw) == false
    end

    test "empty set is subset of anything" do
      script = run("""
      a = set()
      b = {5, 6}
      a.issubset(b)
      """)
      assert Store.get_value(script.last_raw) == true
    end
  end

  describe "issuperset" do
    test "proper superset" do
      script = run("""
      a = {1, 2, 3}
      b = {2, 3}
      a.issuperset(b)
      """)
      assert Store.get_value(script.last_raw) == true
    end

    test "equal sets count as superset" do
      script = run("""
      a = {1, 2}
      b = {1, 2}
      a.issuperset(b)
      """)
      assert Store.get_value(script.last_raw) == true
    end

    test "not a superset when missing elements" do
      script = run("""
      a = {1, 2}
      b = {1, 2, 3}
      a.issuperset(b)
      """)
      assert Store.get_value(script.last_raw) == false
    end
  end

  describe "pop" do
    test "remove and return the only element" do
      script = run("""
      a = {42}
      a.pop()
      """)
      assert Store.get_value(script.last_raw) == 42
      assert Script.get_variable_value(script, "a") == MapSet.new()
    end

    test "pop from empty set raises KeyError" do
      traceback = expr_fail("""
      s = set()
      s.pop()
      """)
      assert traceback.exception == KeyError
    end
  end

  describe "remove" do
    test "remove existing element" do
      script = run("""
      a = {1, 2, 3}
      a.remove(2)
      """)
      # in-place, no return value to check
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 3])
    end

    test "removing missing element raises KeyError" do
      traceback = expr_fail("""
      a = {1, 2}
      a.remove(5)
      """)
      assert traceback.exception == KeyError
    end
  end

  describe "symmetric_difference" do
    test "elements in exactly one set" do
      script = run("""
      a = {1, 2}
      b = {2, 3}
      a.symmetric_difference(b)
      """)
      assert Store.get_value(script.last_raw) == MapSet.new([1, 3])
      # originals unchanged
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2])
      assert Script.get_variable_value(script, "b") == MapSet.new([2, 3])
    end
  end

  describe "symmetric_difference_update" do
    test "in-place symmetric difference" do
      script = run("""
      a = {1, 2}
      b = {2, 3}
      a.symmetric_difference_update(b)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 3])
      # b untouched
      assert Script.get_variable_value(script, "b") == MapSet.new([2, 3])
    end
  end

  describe "union" do
    test "union of two sets" do
      script = run("""
      a = {1, 2}
      b = {2, 3}
      a.union(b)
      """)
      assert Store.get_value(script.last_raw) == MapSet.new([1, 2, 3])
      # originals untouched
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2])
      assert Script.get_variable_value(script, "b") == MapSet.new([2, 3])
    end

    test "union with multiple iterables" do
      script = run("""
      a = {1}
      b = {2, 3}
      c = {3, 4}
      a.union(b, c)
      """)
      assert Store.get_value(script.last_raw) == MapSet.new([1, 2, 3, 4])
    end
  end

  describe "update" do
    test "in-place update with one set" do
      script = run("""
      a = {1}
      b = {2, 3}
      a.update(b)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2, 3])
      assert Script.get_variable_value(script, "b") == MapSet.new([2, 3])
    end

    test "in-place update with multiple iterables" do
      script = run("""
      a = {1}
      b = {2}
      c = {2, 4}
      a.update(b, c)
      """)
      assert Script.get_variable_value(script, "a") == MapSet.new([1, 2, 4])
    end
  end
end
