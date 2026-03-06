defmodule Pythelix.Entity.RangenTest do
  @moduledoc """
  Tests for the random string generator (Rangen) system.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Rangen.Trie
  alias Pythelix.Record
  alias Pythelix.Scripting

  setup do
    Pythelix.World.apply(:static)
    :ok
  end

  describe "Trie" do
    test "insert and lookup" do
      trie = Trie.new()
      trie = Trie.insert(trie, ["a", "b"])

      assert Trie.used?(trie, ["a", "b"]) == true
      assert Trie.used?(trie, ["a"]) == false
      assert Trie.used?(trie, ["a", "c"]) == false
      assert Trie.used?(trie, ["x", "y"]) == false
    end

    test "remove" do
      trie = Trie.new()
      trie = Trie.insert(trie, ["a", "b"])
      trie = Trie.insert(trie, ["a", "c"])

      assert Trie.used?(trie, ["a", "b"]) == true
      assert Trie.used?(trie, ["a", "c"]) == true

      trie = Trie.remove(trie, ["a", "b"])
      assert Trie.used?(trie, ["a", "b"]) == false
      assert Trie.used?(trie, ["a", "c"]) == true
    end

    test "count" do
      trie = Trie.new()
      assert Trie.count(trie) == 0

      trie = Trie.insert(trie, ["a", "b"])
      assert Trie.count(trie) == 1

      trie = Trie.insert(trie, ["a", "c"])
      assert Trie.count(trie) == 2

      trie = Trie.insert(trie, ["b", "a"])
      assert Trie.count(trie) == 3

      trie = Trie.remove(trie, ["a", "b"])
      assert Trie.count(trie) == 2
    end

    test "remove non-existent entry is a no-op" do
      trie = Trie.new()
      trie = Trie.insert(trie, ["a", "b"])

      trie = Trie.remove(trie, ["x", "y"])
      assert Trie.count(trie) == 1
      assert Trie.used?(trie, ["a", "b"]) == true
    end
  end

  defp create_rangen(key, patterns, check_method \\ nil) do
    generic = Record.get_entity("generic/rangen")
    {:ok, entity} = Record.create_entity(key: key, virtual: true, parent: generic)

    Record.set_attribute(key, "patterns", patterns)

    # Copy extended attributes from generic
    for attr <- ["generate", "add", "remove", "clear", "count"] do
      value = Record.get_attribute(generic, attr)
      Record.set_attribute(key, attr, value)
    end

    if check_method do
      Record.set_method(key, "check", [{"text", index: 0, type: :str}], check_method)
    end

    entity
  end

  defp generate_all(key, count) do
    for _ <- 1..count do
      script =
        run_ok("""
        result = !#{key}!.generate()
        """)

      Script.get_variable_value(script, "result")
    end
  end

  describe "generate" do
    test "generate all 8 combinations with patterns [\"ab\", \"ab\", \"ab\"]" do
      create_rangen("rangen/test_gen", ["ab", "ab", "ab"])

      results = generate_all("rangen/test_gen", 8)

      # All 8 should be unique
      assert length(Enum.uniq(results)) == 8

      # All should be 3-character strings made of a/b
      for result <- results do
        assert String.length(result) == 3
        assert String.match?(result, ~r/^[ab]{3}$/)
      end

      # 9th should raise ValueError
      script =
        Scripting.run("""
        try:
          result = !rangen/test_gen!.generate()
        except ValueError:
          result = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["result"] == "exhausted"
    end

    test "cache clear and regenerate" do
      create_rangen("rangen/test_clear", ["ab", "ab", "ab"])

      # Generate all 8
      results1 = generate_all("rangen/test_clear", 8)
      assert length(Enum.uniq(results1)) == 8

      # Clear
      run_ok("""
      !rangen/test_clear!.clear()
      """)

      # Generate all 8 again
      results2 = generate_all("rangen/test_clear", 8)
      assert length(Enum.uniq(results2)) == 8
    end

    test "check filtering rejects 'aaa'" do
      create_rangen(
        "rangen/test_check",
        ["ab", "ab", "ab"],
        "return text != 'aaa'"
      )

      # Should only generate 7 (aaa is rejected by check)
      results = generate_all("rangen/test_check", 7)
      assert length(Enum.uniq(results)) == 7
      refute "aaa" in results

      # 8th should raise ValueError
      script =
        Scripting.run("""
        try:
          result = !rangen/test_check!.generate()
        except ValueError:
          result = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["result"] == "exhausted"
    end
  end

  describe "add and remove" do
    test "add a string manually, then it cannot be generated" do
      create_rangen("rangen/test_add", ["ab", "ab", "ab"])

      # Manually add "aab"
      run_ok("""
      !rangen/test_add!.add("aab")
      """)

      # Generate the remaining 7
      results = generate_all("rangen/test_add", 7)
      assert length(Enum.uniq(results)) == 7
      refute "aab" in results

      # 8th should exhaust
      script =
        Scripting.run("""
        try:
          result = !rangen/test_add!.generate()
        except ValueError:
          result = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["result"] == "exhausted"
    end

    test "remove a string, then it can be generated again" do
      create_rangen("rangen/test_remove", ["ab", "ab", "ab"])

      # Generate all 8
      generate_all("rangen/test_remove", 8)

      # Remove one
      run_ok("""
      !rangen/test_remove!.remove("aab")
      """)

      # Should be able to generate exactly 1 more (the removed one)
      results = generate_all("rangen/test_remove", 1)
      assert results == ["aab"]
    end
  end

  describe "count" do
    test "count attribute reflects number of entries" do
      create_rangen("rangen/test_count", ["ab", "ab", "ab"])

      script =
        run_ok("""
        ent = !rangen/test_count!
        c0 = ent.count
        ent.generate()
        c1 = ent.count
        ent.generate()
        c2 = ent.count
        ent.clear()
        c3 = ent.count
        """)

      assert Script.get_variable_value(script, "c0") == 0
      assert Script.get_variable_value(script, "c1") == 1
      assert Script.get_variable_value(script, "c2") == 2
      assert Script.get_variable_value(script, "c3") == 0
    end
  end
end
