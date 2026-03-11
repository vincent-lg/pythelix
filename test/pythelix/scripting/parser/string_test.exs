defmodule Pythelix.Scripting.Parser.StringTest do
  @moduledoc """
  Module to test that strings are properly parsed.
  """

  use Pythelix.ScriptingCase

  test "a one-word string using single quotes" do
    ast = eval_ok("'thing'")
    assert ast == "thing"
  end

  test "a multiple-word string using single quotes" do
    ast = eval_ok("'this thing'")
    assert ast == "this thing"
  end

  test "a multiple-word string using single quotes and containing an escaped single quote" do
    ast = eval_ok("'this thing\\'s great'")
    assert ast == "this thing's great"
  end

  test "a multiple-word string using single quotes and containg accented letters" do
    ast = eval_ok("'on est bientôt en été'")
    assert ast == "on est bientôt en été"
  end

  test "a multiple-word string using single quotes and containg accented letters and double quotes" do
    ast = eval_ok("'on est \"bientôt\\\" en été'")
    assert ast == "on est \"bientôt\" en été"
  end

  test "a multiple-word string using single quotes and containg escape newsline" do
    ast = eval_ok("'bientôt\\nété'")
    assert ast == "bientôt\nété"
  end

  test "a single-quoted string with an unescape newsline should fail" do
    eval_fail("'abc\nde'")
  end

  test "a one-word string using double quotes" do
    ast = eval_ok("\"thing\"")
    assert ast == "thing"
  end

  test "a multiple-word string using double quotes" do
    ast = eval_ok("\"this thing\"")
    assert ast == "this thing"
  end

  test "a multiple-word string using double quotes and containing a single quote" do
    ast = eval_ok("\"this thing's great\"")
    assert ast == "this thing's great"
  end

  test "a multiple-word string using double quotes and containg accented letters" do
    ast = eval_ok("\"on est bientôt en été\"")
    assert ast == "on est bientôt en été"
  end

  test "a multiple-word string using double quotes and containg accented letters and escaped quotes" do
    ast = eval_ok("\"on est \\\"bientôt\\\" en été\"")
    assert ast == "on est \"bientôt\" en été"
  end

  test "a multiple-word string using double quotes and containg escape newsline" do
    ast = eval_ok("\"bientôt\\nété\"")
    assert ast == "bientôt\nété"
  end

  test "a double-quoted string with an unescape newsline should fail" do
    eval_fail("\"abc\nde\"")
  end

  describe "multiline strings (triple-quoted)" do
    test "strips leading and trailing newlines" do
      ast = eval_ok("\"\"\"\nThis\nis\njust\nfive\nlines\n\"\"\"")
      assert ast == "This\nis\njust\nfive\nlines"
    end

    test "dedents based on common indentation" do
      ast = eval_ok("\"\"\"\n    This\n    is\n    just\n    five\n    lines\n\"\"\"")
      assert ast == "This\nis\njust\nfive\nlines"
    end

    test "dedents with mixed indentation levels" do
      ast = eval_ok("\"\"\"\n    Hello\n        World\n    End\n\"\"\"")
      assert ast == "Hello\n    World\nEnd"
    end

    test "handles empty string" do
      ast = eval_ok("\"\"\"\"\"\"")
      assert ast == ""
    end

    test "handles content without newlines" do
      ast = eval_ok("\"\"\"ok\"\"\"")
      assert ast == "ok"
    end

    test "works with single-quote triple strings" do
      ast = eval_ok("'''\nThis\nis\nok\n'''")
      assert ast == "This\nis\nok"
    end

    test "dedents indented multiline string (closing delimiter indented less)" do
      # Simulates:
      #     text = """
      #         This
      #         is
      #         just
      #         five
      #         lines
      #     """
      # The closing line's whitespace is stripped, so dedent is based on content lines (8 spaces).
      ast =
        eval_ok(
          "\"\"\"\n        This\n        is\n        just\n        five\n        lines\n    \"\"\""
        )

      assert ast == "This\nis\njust\nfive\nlines"
    end
  end
end
