defmodule Pythelix.Scripting.Namespace.Module.DisplayTest do
  @moduledoc """
  Tests for the display module: HorizontalList, dedent, wrap.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.{HorizontalList, HorizontalListGroup}

  describe "display.HorizontalList — creation" do
    test "creates a HorizontalList with default options" do
      script =
        run("""
        result = display.HorizontalList()
        """)

      result = Script.get_variable_value(script, "result")
      assert %HorizontalList{indent: 2, columns: 3, col_width: 20, groups: []} = result
    end

    test "creates a HorizontalList with custom options" do
      script =
        run("""
        result = display.HorizontalList(indent=4, columns=2, col_width=15)
        """)

      result = Script.get_variable_value(script, "result")
      assert %HorizontalList{indent: 4, columns: 2, col_width: 15} = result
    end
  end

  describe "display.HorizontalList — add_group" do
    test "adds a group with a title" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group("General")
        """)

      group = Script.get_variable_value(script, "group")
      assert %HorizontalListGroup{title: "General", entries: []} = group
    end

    test "adds a group without a title" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group()
        """)

      group = Script.get_variable_value(script, "group")
      assert %HorizontalListGroup{title: "", entries: []} = group
    end

    test "groups are stored in the list" do
      script =
        run("""
        hl = display.HorizontalList()
        hl.add_group("A")
        hl.add_group("B")
        result = hl.groups
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
    end
  end

  describe "display.HorizontalListGroup — add_entry" do
    test "adds entries to a group" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group("General")
        group.add_entry("look")
        group.add_entry("quit")
        entries = group.entries
        """)

      entries = Script.get_variable_value(script, "entries")
      assert entries == ["look", "quit"]
    end
  end

  describe "display.HorizontalList — format" do
    test "formats a simple horizontal list" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group("General")
        group.add_entry("inventory")
        group.add_entry("look")
        group.add_entry("quit")
        group.add_entry("rest")
        group.add_entry("return")
        result = hl.format()
        """)

      result = Script.get_variable_value(script, "result")

      expected =
        "General\n" <>
          "  inventory           look                quit\n" <>
          "  rest                return"

      assert result == expected
    end

    test "formats multiple groups" do
      script =
        run("""
        hl = display.HorizontalList()
        g1 = hl.add_group("General")
        g1.add_entry("look")
        g1.add_entry("quit")
        g2 = hl.add_group("Admin")
        g2.add_entry("goto")
        result = hl.format()
        """)

      result = Script.get_variable_value(script, "result")

      expected =
        "General\n" <>
          "  look                quit\n" <>
          "Admin\n" <>
          "  goto"

      assert result == expected
    end

    test "formats with custom options" do
      script =
        run("""
        hl = display.HorizontalList(indent=4, columns=2, col_width=10)
        group = hl.add_group("Test")
        group.add_entry("a")
        group.add_entry("b")
        group.add_entry("c")
        result = hl.format()
        """)

      result = Script.get_variable_value(script, "result")

      expected =
        "Test\n" <>
          "    a         b\n" <>
          "    c"

      assert result == expected
    end

    test "formats a group without title" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group()
        group.add_entry("alpha")
        group.add_entry("beta")
        result = hl.format()
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "  alpha               beta"
    end
  end

  describe "display — writable options" do
    test "can change group title" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group("Old")
        group.title = "New"
        result = group.title
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "New"
    end

    test "can change list indent" do
      script =
        run("""
        hl = display.HorizontalList()
        hl.indent = 4
        result = hl.indent
        """)

      result = Script.get_variable_value(script, "result")
      assert result == 4
    end

    test "can change list columns" do
      script =
        run("""
        hl = display.HorizontalList()
        hl.columns = 5
        result = hl.columns
        """)

      result = Script.get_variable_value(script, "result")
      assert result == 5
    end

    test "can change list col_width" do
      script =
        run("""
        hl = display.HorizontalList()
        hl.col_width = 30
        result = hl.col_width
        """)

      result = Script.get_variable_value(script, "result")
      assert result == 30
    end
  end

  describe "display — repr and str" do
    test "repr shows summary" do
      script =
        run("""
        hl = display.HorizontalList()
        hl.add_group("A")
        result = repr(hl)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "<HorizontalList (1 groups)>"
    end

    test "str returns formatted output" do
      script =
        run("""
        hl = display.HorizontalList()
        group = hl.add_group()
        group.add_entry("test")
        result = str(hl)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "  test"
    end
  end

  describe "display.dedent" do
    test "removes common leading whitespace" do
      script =
        run("""
        result = display.dedent("    hello\\n    world")
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "hello\nworld"
    end

    test "removes common indentation with mixed levels" do
      script =
        run("""
        result = display.dedent("    hello\\n        world\\n    end")
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "hello\n    world\nend"
    end

    test "handles empty lines" do
      script =
        run("""
        result = display.dedent("    hello\\n\\n    world")
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "hello\n\nworld"
    end

    test "handles no indentation" do
      script =
        run("""
        result = display.dedent("hello\\nworld")
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "hello\nworld"
    end
  end

  describe "display.wrap — returns a list" do
    test "wraps text at default width (70)" do
      script =
        run("""
        result = display.wrap("a b c d e f g h i j k l m n o p q r s t u v w x y z a b c d e f g h i j k l m n o p q r s t u v w x y z")
        """)

      result = Script.get_variable_value(script, "result")
      assert is_list(result)
      assert Enum.all?(result, &(String.length(&1) <= 70))
    end

    test "wraps text at custom width" do
      script =
        run("""
        result = display.wrap("hello world foo bar", width=10)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["hello", "world foo", "bar"]
    end

    test "does not break short lines" do
      script =
        run("""
        result = display.wrap("short line", width=70)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["short line"]
    end

    test "replaces newlines by default (replace_whitespace=True)" do
      script =
        run("""
        result = display.wrap("line one\\nline two", width=70)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["line one line two"]
    end

    test "preserves newlines when replace_whitespace=False" do
      script =
        run("""
        result = display.fill("hello\\nworld", width=70, replace_whitespace=False)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == "hello\nworld"
    end
  end

  describe "display.wrap — initial_indent and subsequent_indent" do
    test "applies initial_indent to first line" do
      script =
        run("""
        result = display.wrap("hello world foo bar baz", width=20, initial_indent="  ")
        """)

      result = Script.get_variable_value(script, "result")
      first = List.first(result)
      assert String.starts_with?(first, "  ")
    end

    test "applies subsequent_indent to following lines" do
      script =
        run("""
        result = display.wrap("hello world foo bar baz qux", width=15, subsequent_indent="    ")
        """)

      result = Script.get_variable_value(script, "result")

      if length(result) > 1 do
        rest = Enum.drop(result, 1)
        assert Enum.all?(rest, &String.starts_with?(&1, "    "))
      end
    end
  end

  describe "display.wrap — break_long_words" do
    test "breaks long words by default" do
      script =
        run("""
        result = display.wrap("aaaaabbbbbccccc", width=5)
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) > 1
      assert Enum.all?(result, &(String.length(&1) <= 5))
    end

    test "does not break long words when break_long_words=False" do
      script =
        run("""
        result = display.wrap("aaaaabbbbbccccc", width=5, break_long_words=False)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["aaaaabbbbbccccc"]
    end
  end

  describe "display.wrap — break_on_hyphens" do
    test "breaks on hyphens by default" do
      script =
        run("""
        result = display.wrap("a well-known fact", width=10)
        """)

      result = Script.get_variable_value(script, "result")
      assert Enum.any?(result, &String.ends_with?(&1, "-"))
    end

    test "does not break on hyphens when break_on_hyphens=False" do
      script =
        run("""
        result = display.wrap("a well-known fact", width=10, break_on_hyphens=False)
        """)

      result = Script.get_variable_value(script, "result")
      # "well-known" should stay together on one line.
      flat = Enum.join(result, " ")
      assert String.contains?(flat, "well-known")
    end
  end

  describe "display.wrap — max_lines and placeholder" do
    test "truncates with placeholder when max_lines is set" do
      script =
        run("""
        result = display.wrap("one two three four five six seven eight nine ten", width=10, max_lines=2)
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
      assert String.contains?(List.last(result), "[...]")
    end

    test "uses custom placeholder" do
      script =
        run("""
        result = display.wrap("one two three four five six seven", width=10, max_lines=1, placeholder="...")
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 1
      assert String.ends_with?(List.first(result), "...")
    end
  end

  describe "display.fill" do
    test "returns a string instead of a list" do
      script =
        run("""
        result = display.fill("hello world foo bar", width=10)
        """)

      result = Script.get_variable_value(script, "result")
      assert is_binary(result)
      assert result == "hello\nworld foo\nbar"
    end

    test "accepts same options as wrap" do
      script =
        run("""
        result = display.fill("hello world foo bar baz", width=15, initial_indent="> ", subsequent_indent="  ")
        """)

      result = Script.get_variable_value(script, "result")
      lines = String.split(result, "\n")
      assert String.starts_with?(List.first(lines), "> ")

      if length(lines) > 1 do
        assert Enum.all?(Enum.drop(lines, 1), &String.starts_with?(&1, "  "))
      end
    end
  end
end
