defmodule Pythelix.Entity.RangenTest do
  @moduledoc """
  Tests for the random string generator (Rangen) system.
  """

  use Pythelix.ScriptingCase

  import Ecto.Query, only: [from: 2]

  alias Pythelix.Rangen
  alias Pythelix.Rangen.Trie
  alias Pythelix.Rangen.TrieServer
  alias Pythelix.Record
  alias Pythelix.Record.RangenEntry
  alias Pythelix.Repo
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

    test "an empty trie holds nothing" do
      trie = Trie.new()

      assert Trie.count(trie) == 0
      assert Trie.used?(trie, []) == false
      assert Trie.used?(trie, ["a"]) == false
    end

    test "inserting the same parts twice only counts once" do
      trie =
        Trie.new()
        |> Trie.insert(["a", "b"])
        |> Trie.insert(["a", "b"])

      assert Trie.count(trie) == 1

      # ... and a single remove is enough to free it again.
      trie = Trie.remove(trie, ["a", "b"])
      assert Trie.used?(trie, ["a", "b"]) == false
    end

    test "an entry that is a prefix of another coexists with it" do
      trie =
        Trie.new()
        |> Trie.insert(["a"])
        |> Trie.insert(["a", "b"])

      assert Trie.count(trie) == 2
      assert Trie.used?(trie, ["a"]) == true
      assert Trie.used?(trie, ["a", "b"]) == true

      trie = Trie.remove(trie, ["a"])
      assert Trie.used?(trie, ["a"]) == false
      assert Trie.used?(trie, ["a", "b"]) == true
    end

    test "removing the last entry prunes the branch" do
      trie =
        Trie.new()
        |> Trie.insert(["a", "b", "c"])
        |> Trie.remove(["a", "b", "c"])

      assert trie == Trie.new()
      assert Trie.count(trie) == 0
    end
  end

  describe "patterns" do
    test "parse_patterns splits each pattern into its characters" do
      assert Rangen.parse_patterns(["ab", "012"]) == [["a", "b"], ["0", "1", "2"]]
      assert Rangen.parse_patterns([]) == []
    end

    test "parse_patterns handles multi-byte characters" do
      assert Rangen.parse_patterns(["éè"]) == [["é", "è"]]
    end

    test "decompose_string takes one character per pattern" do
      parsed = Rangen.parse_patterns(["ab", "ab", "ab"])

      assert Rangen.decompose_string("aab", parsed) == ["a", "a", "b"]
    end

    test "decompose_string ignores characters beyond the last pattern" do
      parsed = Rangen.parse_patterns(["ab", "ab", "ab"])

      assert Rangen.decompose_string("aabb", parsed) == ["a", "a", "b"]
    end

    test "decompose_string stops when the string is shorter than the patterns" do
      parsed = Rangen.parse_patterns(["ab", "ab", "ab"])

      assert Rangen.decompose_string("a", parsed) == ["a"]
      assert Rangen.decompose_string("", parsed) == []
    end

    test "decompose_string works on multi-byte characters" do
      parsed = Rangen.parse_patterns(["éè", "ab"])

      assert Rangen.decompose_string("éa", parsed) == ["é", "a"]
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

  # The registry unregisters a dead server asynchronously, so give it a moment.
  defp wait_until(condition, attempts \\ 50) do
    cond do
      condition.() -> :ok
      attempts == 0 -> flunk("condition never became true")
      true -> Process.sleep(10) && wait_until(condition, attempts - 1)
    end
  end

  defp values_in_db(key) do
    Repo.all(from e in RangenEntry, where: e.generator_key == ^key, select: e.value)
  end

  # Write a temporary worldlet file and apply it, as `apply` would in game.
  defp worldlet(content) do
    directory = Path.join(System.tmp_dir!(), "rangen_#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    path = Path.join(directory, "rangen.txt")
    File.write!(path, content)

    assert {:ok, _path, _number} = Pythelix.World.apply(path)

    :ok
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

    test "each position draws from its own pattern" do
      create_rangen("rangen/test_mixed", ["ab", "012"])

      results = generate_all("rangen/test_mixed", 6)

      assert length(Enum.uniq(results)) == 6

      for result <- results do
        assert String.match?(result, ~r/^[ab][012]$/)
      end
    end

    test "a character repeated in a pattern yields a single combination" do
      create_rangen("rangen/test_dup", ["aa"])

      script =
        Scripting.run("""
        one = !rangen/test_dup!.generate()
        try:
          two = !rangen/test_dup!.generate()
        except ValueError:
          two = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["one"] == "a"
      assert script.variables["two"] == "exhausted"
    end

    test "check is called on every prefix, pruning whole branches" do
      create_rangen("rangen/test_prefix", ["ab", "ab"], "return not text.startswith('a')")

      results = generate_all("rangen/test_prefix", 2)

      assert Enum.sort(results) == ["ba", "bb"]

      script =
        Scripting.run("""
        try:
          result = !rangen/test_prefix!.generate()
        except ValueError:
          result = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["result"] == "exhausted"
    end

    test "a check that rejects every prefix exhausts immediately" do
      # `len(text) == 2` is never true for the one-character prefixes `check`
      # receives first, so no branch is ever explored.
      create_rangen("rangen/test_never", ["ab", "ab"], "return len(text) == 2")

      script =
        Scripting.run("""
        try:
          result = !rangen/test_never!.generate()
        except ValueError:
          result = "exhausted"
        endtry
        """)

      assert script.error == nil
      assert script.variables["result"] == "exhausted"
    end

    test "two generators keep separate sets of used strings" do
      create_rangen("rangen/test_first", ["ab", "ab", "ab"])
      create_rangen("rangen/test_second", ["ab", "ab", "ab"])

      first = generate_all("rangen/test_first", 8)
      assert length(Enum.uniq(first)) == 8

      # The first one is exhausted, the second one is untouched.
      second = generate_all("rangen/test_second", 8)
      assert length(Enum.uniq(second)) == 8
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

    test "removing a string that was never used is a no-op" do
      create_rangen("rangen/test_remove_unknown", ["ab", "ab", "ab"])

      script =
        run_ok("""
        ent = !rangen/test_remove_unknown!
        ent.add("aab")
        ent.remove("bba")
        after = ent.count
        """)

      assert Script.get_variable_value(script, "after") == 1
      assert values_in_db("rangen/test_remove_unknown") == ["aab"]
    end
  end

  describe "database" do
    test "generated and added strings are stored" do
      create_rangen("rangen/test_db", ["ab", "ab", "ab"])

      run_ok("""
      !rangen/test_db!.add("aab")
      """)

      generated = generate_all("rangen/test_db", 2)

      assert Enum.sort(values_in_db("rangen/test_db")) == Enum.sort(["aab" | generated])
    end

    test "remove deletes the row" do
      create_rangen("rangen/test_db_remove", ["ab", "ab", "ab"])

      run_ok("""
      ent = !rangen/test_db_remove!
      ent.add("aab")
      ent.add("bba")
      ent.remove("aab")
      """)

      assert values_in_db("rangen/test_db_remove") == ["bba"]
    end

    test "clear deletes every row for that generator only" do
      create_rangen("rangen/test_db_clear", ["ab", "ab", "ab"])
      create_rangen("rangen/test_db_kept", ["ab", "ab", "ab"])

      run_ok("""
      !rangen/test_db_clear!.add("aab")
      !rangen/test_db_kept!.add("aab")
      !rangen/test_db_clear!.clear()
      """)

      assert values_in_db("rangen/test_db_clear") == []
      assert values_in_db("rangen/test_db_kept") == ["aab"]
    end

    test "entries survive the loss of the trie server" do
      create_rangen("rangen/test_restart", ["ab", "ab", "ab"])

      generated = generate_all("rangen/test_restart", 3)
      assert Rangen.count("rangen/test_restart") == 3

      # Simulate a restart: the in-memory trie is gone, only the rows remain.
      [{pid, _}] = Registry.lookup(Pythelix.Rangen.Registry, "rangen/test_restart")
      :ok = DynamicSupervisor.terminate_child(Pythelix.Rangen.Supervisor, pid)
      wait_until(fn -> not TrieServer.alive?("rangen/test_restart") end)

      Rangen.warmup()
      Rangen.ensure_trie("rangen/test_restart", Rangen.parse_patterns(["ab", "ab", "ab"]))

      assert Rangen.count("rangen/test_restart") == 3

      # The five remaining combinations are still generated, then it exhausts.
      remaining = generate_all("rangen/test_restart", 5)
      assert length(Enum.uniq(generated ++ remaining)) == 8
    end
  end

  describe "worldlets" do
    test "a rangen defined in a worldlet generates values matching its patterns" do
      worldlet("""
      !rangen/phone!
      parent = "generic/rangen"
      patterns = ["0", "1234", "0123456789", "0123456789"]

      def check(self, text):
          return not text.startswith("013")
      """)

      script =
        run_ok("""
        number = !rangen/phone!.generate()
        total = !rangen/phone!.count
        """)

      number = Script.get_variable_value(script, "number")

      assert String.match?(number, ~r/^0[1-4]\d\d$/)
      refute String.starts_with?(number, "013")
      assert Script.get_variable_value(script, "total") == 1
      assert values_in_db("rangen/phone") == [number]
    end

    test "a check can consult an attribute of the generator" do
      # The documented way to keep a list of forbidden values: guard on the
      # length first, since `check` also receives the shorter prefixes.
      worldlet("""
      !rangen/guarded!
      parent = "generic/rangen"
      patterns = ["ab", "ab"]
      forbidden = ["aa", "ab"]

      def check(self, text):
          if len(text) < 2:
              return True
          endif

          return text not in self.forbidden
      """)

      results = generate_all("rangen/guarded", 2)

      assert Enum.sort(results) == ["ba", "bb"]
    end

    test "a value taken from a generator can be given back" do
      worldlet("""
      !rangen/pool!
      parent = "generic/rangen"
      patterns = ["ab", "ab"]

      !obj/subscriber!
      name = "subscriber"
      """)

      script =
        run_ok("""
        subscriber = !obj/subscriber!
        before = hasattr(subscriber, "phone_number")
        subscriber.phone_number = !rangen/pool!.generate()
        after = hasattr(subscriber, "phone_number")
        taken = !rangen/pool!.count
        !rangen/pool!.remove(subscriber.phone_number)
        given_back = !rangen/pool!.count
        """)

      assert Script.get_variable_value(script, "before") == false
      assert Script.get_variable_value(script, "after") == true
      assert Script.get_variable_value(script, "taken") == 1
      assert Script.get_variable_value(script, "given_back") == 0
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
