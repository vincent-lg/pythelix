defmodule Pythelix.Scripting.Namespace.DictTest do
  @moduledoc """
  Module to test the dict API.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.Dict

  describe "creation" do
    test "an empty dictionary" do
      dict = expr_ok("{}")
      assert length(Dict.keys(dict)) == 0
    end

    test "a dictionary with one key/value" do
      dict = expr_ok("{'key': 2 + 5}")
      assert Dict.items(dict) == [{"key", 7}]
    end

    test "a dictionary with two key/value pairs" do
      dict = expr_ok("{'key': -2, 4 + 4: 'ok'}")
      assert Dict.items(dict) == [{"key", -2}, {8, "ok"}]
    end
  end

  describe "__getitem__" do
    test "a dictionary without the specified key" do
      traceback = expr_fail("""
      d = {}
      d[8]
      """)
      assert traceback.exception == KeyError
    end

    test "a dictionary with the key" do
      value = expr_ok("""
      d = {"ok": 8}
      d["ok"]
      """)
      assert value == 8
    end

    test "an embeeded dictionary without the specified key" do
      traceback = expr_fail("""
      d = {8: {}}
      d[8][0]
      """)
      assert traceback.exception == KeyError
      assert traceback.message == "0"
    end

    test "an embedded dictionary with the key" do
      value = expr_ok("""
      d = {"ok": {8: 3}}
      d["ok"][8]
      """)
      assert value == 3
    end
  end

  describe "__setitem__" do
    test "a dictionary without the specified key" do
      dict = expr_ok("""
      d = {}
      d[8] = 'ok'
      d
      """)
      assert Dict.items(dict) == [{8, "ok"}]
    end

    test "a dictionary with the key" do
      dict = expr_ok("""
      d = {"ok": 8}
      d["ok"] = 5
      d
      """)
      assert Dict.items(dict) == [{"ok", 5}]
    end

    test "an embedded dictionary" do
      dict = expr_ok("""
      d = {"ok": {8: 3}}
      d["ok"][8] = 9
      d["ok"]
      """)
      assert Dict.items(dict) == [{8, 9}]
    end

    test "in-place: a dictionary without the specified key" do
      traceback = expr_fail("""
      d = {}
      d[8] += 2
      d
      """)
      assert traceback.exception == KeyError
      assert traceback.message == "8"
    end

    test "in-place: a dictionary with the key" do
      dict = expr_ok("""
      d = {"ok": 8}
      d["ok"] -= 2
      d
      """)
      assert Dict.items(dict) == [{"ok", 6}]
    end

    test "in-place: an embedded dictionary" do
      dict = expr_ok("""
      d = {"ok": {8: 3}}
      d["ok"][8] *= 2
      d["ok"]
      """)
      assert Dict.items(dict) == [{8, 6}]
    end
  end

  describe "clear" do
    test "clear an empty dictionary" do
      dict = expr_ok("""
      d = {}
      d.clear()
      d
      """)
      assert length(Dict.keys(dict)) == 0
    end

    test "clear a dictionary with one key/value" do
      dict = expr_ok("""
      d = {'key': 2 + 5}
      d.clear()
      d
      """)
      assert length(Dict.keys(dict)) == 0
    end

    test "clear a dictionary with two key/value pairs" do
      dict = expr_ok("""
      d = {'key': -2, 4 + 4: 'ok'}
      d.clear()
      d
      """)
      assert length(Dict.keys(dict)) == 0
    end
  end

  describe "copy" do
    test "an empty dictionary" do
      dict = expr_ok("""
      d = {}
      d.copy()
      """)
      assert length(Dict.keys(dict)) == 0
    end

    test "a dictionary with one key/value" do
      dict = expr_ok("""
      d = {'key': 2 + 5}
      d.copy()
      """)
      assert Dict.items(dict) == [{"key", 7}]
    end

    test "a dictionary with two key/value pairs" do
      dict = expr_ok("""
      d = {'key': -2, 4 + 4: 'ok'}
      d.copy()
      """)
      assert Dict.items(dict) == [{"key", -2}, {8, "ok"}]
    end
  end

  describe "get" do
    test "an empty dictionary without default values" do
      value = expr_ok("""
      d = {}
      d.get("something")
      """)
      assert value == :none
    end

    test "an empty dictionary with default values" do
      value = expr_ok("""
      d = {}
      d.get("something", 0)
      """)
      assert value == 0
    end

    test "a non-empty dictionary without default values" do
      value = expr_ok("""
      d = {"ok": 8}
      d.get("something")
      """)
      assert value == :none
    end

    test "a non-empty dictionary with default values" do
      value = expr_ok("""
      d = {"ok": 8}
      d.get("something", 0)
      """)
      assert value == 0
    end

    test "correct, a non-empty dictionary without default values" do
      value = expr_ok("""
      d = {"ok": 8}
      d.get("ok")
      """)
      assert value == 8
    end

    test "correct, a non-empty dictionary with default values" do
      value = expr_ok("""
      d = {"ok": 8}
      d.get("ok", 0)
      """)
      assert value == 8
    end
  end

  describe "items" do
    test "an empty dictionary" do
      items = expr_ok("""
      d = {}
      d.items()
      """)
      assert items == []
    end

    test "a dictionary with one key/value" do
      items = expr_ok("""
      d = {'key': 2 + 5}
      d.items()
      """)
      assert items == [["key", 7]]
    end

    test "a dictionary with two key/value pairs" do
      items = expr_ok("""
      d = {'key': -2, 4 + 4: 'ok'}
      d.items()
      """)
      assert items == [["key", -2], [8, "ok"]]
    end
  end

  describe "keys" do
    test "an empty dictionary" do
      keys = expr_ok("""
      d = {}
      d.keys()
      """)
      assert keys == []
    end

    test "a dictionary with one key/value" do
      keys = expr_ok("""
      d = {'key': 2 + 5}
      d.keys()
      """)
      assert keys == ["key"]
    end

    test "a dictionary with two key/value pairs" do
      keys = expr_ok("""
      d = {'key': -2, 4 + 4: 'ok'}
      d.keys()
      """)
      assert keys == ["key", 8]
    end
  end

  describe "pop" do
    test "an empty dictionary and no default" do
      traceback = expr_fail("""
      d = {}
      d.pop("something")
      """)
      assert traceback.exception == KeyError
      assert traceback.message == "something"
    end

    test "an empty dictionary with default" do
      value = expr_ok("""
      d = {}
      d.pop("something", None)
      """)
      assert value == :none
    end

    test "a dictionary and no default" do
      traceback = expr_fail("""
      d = {1: 8}
      d.pop("something")
      """)
      assert traceback.exception == KeyError
      assert traceback.message == "something"
    end

    test "a dictionary with default" do
      value = expr_ok("""
      d = {1: 8}
      d.pop("something", None)
      """)
      assert value == :none
    end

    test "correct, a dictionary and no default" do
      value = expr_ok("""
      d = {1: 8}
      d.pop(1)
      """)
      assert value == 8
    end

    test "correct, a dictionary with default" do
      value = expr_ok("""
      d = {1: 8}
      d.pop(1, None)
      """)
      assert value == 8
    end
  end

  describe "popitem" do
    test "an empty dictionary" do
      traceback = expr_fail("""
      d = {}
      d.popitem()
      """)
      assert traceback.exception == KeyError
    end

    test "a dictionary with two keys should return the last" do
      value = expr_ok("""
      d = {"first": 1, "second": 2}
      d.popitem()
      """)
      assert value == ["second", 2]
    end
  end

  describe "setdefault" do
    test "an empty dictionary" do
      items = expr_ok("""
      d = {}
      d.setdefault("something", 2)
      d.items()
      """)
      assert items == [["something", 2]]
    end

    test "a dictionary with existing key should not update" do
      items = expr_ok("""
      d = {"first": 1}
      d.setdefault("first", 2)
      d.items()
      """)
      assert items == [["first", 1]]
    end
  end

  describe "update" do
    test "update with keyword arguments" do
      items = expr_ok("""
      d = {"first": 1, "second": 2}
      d.update(second=3, third=4)
      d.items()
      """)
      assert items == [["first", 1], ["second", 3], ["third", 4]]
    end

    test "update with dictionary and keyword arguments" do
      items = expr_ok("""
      e = {"second": 5, "fourth": 6}
      d = {"first": 1, "second": 2}
      d.update(e, second=3, third=4)
      d.items()
      """)
      assert items == [["first", 1], ["second", 3], ["fourth", 6], ["third", 4]]
    end

    test "update with dictionary only" do
      items = expr_ok("""
      e = {"second": 5, "fourth": 6}
      d = {"first": 1, "second": 2}
      d.update(e)
      d.items()
      """)
      assert items == [["first", 1], ["second", 5], ["fourth", 6]]
    end
  end

  describe "values" do
    test "an empty dictionary" do
      values = expr_ok("""
      d = {}
      d.values()
      """)
      assert values == []
    end

    test "a dictionary with one key/value" do
      values = expr_ok("""
      d = {'key': 2 + 5}
      d.values()
      """)
      assert values == [7]
    end

    test "a dictionary with two key/value pairs" do
      values = expr_ok("""
      d = {'key': -2, 4 + 4: 'ok'}
      d.values()
      """)
      assert values == [-2, "ok"]
    end
  end
end
