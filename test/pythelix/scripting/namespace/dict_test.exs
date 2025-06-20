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
end
