defmodule Pythelix.Scripting.DiagnosticTest do
  use ExUnit.Case, async: true

  alias Pythelix.Scripting.Diagnostic

  defp check(code, opts \\ []), do: Diagnostic.check(code, opts)

  defp one(code, opts \\ []) do
    assert [diagnostic] = check(code, opts)
    diagnostic
  end

  describe "valid Pythello" do
    test "an if block closed with endif" do
      assert [] == check("if x:\n    y = 1\nendif\n")
    end

    test "a loop closed with done" do
      assert [] == check("for e in l:\n    x = e\ndone\n")
    end

    test "a try block closed with endtry" do
      assert [] == check("try:\n    x = 1\nexcept ValueError:\n    y = 2\nendtry\n")
    end

    test "an f-string" do
      assert [] == check(~s|character.msg(f"You roll a {result}.")\n|)
    end
  end

  describe "blocks left open" do
    test "an if without endif names the rule and the keyword" do
      diagnostic = one("if result == 1:\n    character.msg(\"one\")\n")

      assert diagnostic.line == 1
      assert diagnostic.message =~ "`if` opened on line 1 is never closed"
      assert diagnostic.message =~ "endif"
      assert diagnostic.hint =~ "not by indentation"
      assert diagnostic.doc == "scripting.md#conditions"
    end

    test "a for without done" do
      diagnostic = one("for e in l:\n    x = e\n")

      assert diagnostic.message =~ "`for` opened on line 1 is never closed"
      assert diagnostic.message =~ "done"
      assert diagnostic.doc == "scripting.md#loops"
    end

    test "a closing keyword that doesn't match what is open" do
      diagnostic = one("for e in l:\n    if e:\n    done\n")

      assert diagnostic.message =~ "found `done`"
      assert diagnostic.message =~ "`if` opened on line 2 is still open"
    end

    test "a block whose last line ends in a string still blames the block" do
      # The scanner looks ahead after a closing quote, in case a third one
      # follows. That must not hide the `if` still open underneath it.
      diagnostic = one("if self.broken:\n    return \"yes\"\n")

      assert diagnostic.message =~ "`if` opened on line 1 is never closed"
      refute diagnostic.message =~ "string"
    end

    test "an unclosed parenthesis" do
      diagnostic = one("x = character.msg(\"hi\"\n")

      assert diagnostic.message =~ "`(` opened on line 1 is never closed"
    end
  end

  describe "Python habits that don't carry over" do
    test "endfor is named as not being a keyword" do
      diagnostic = one("for a in b:\n    x = 1\nendfor\n")

      assert diagnostic.message =~ "not Pythello keywords"
      assert diagnostic.hint =~ "close with `done`"
      assert diagnostic.line == 3
    end

    test "a list comprehension points at the bracket" do
      diagnostic = one("names = [c.name for c in self.contents]\n")

      assert diagnostic.message =~ "list comprehensions are not supported"
      assert diagnostic.column == 9
    end

    test "a dict comprehension" do
      diagnostic = one("d = {k: v for k, v in pairs}\n")

      assert diagnostic.message =~ "dict and set comprehensions are not supported"
    end

    test "a lambda" do
      diagnostic = one("f = lambda x: x + 1\n")

      assert diagnostic.message =~ "lambdas are not supported"
      assert diagnostic.hint =~ "`def`"
    end

    test "capturing an exception in a variable" do
      diagnostic = one("try:\n    x = 1\nexcept ValueError as e:\n    y = 2\nendtry\n")

      assert diagnostic.message =~ "cannot be captured in a variable"
      assert diagnostic.line == 3
    end

    test "an import" do
      diagnostic = one("import random\n")

      assert diagnostic.message =~ "no `import`"
    end

    test "a class" do
      diagnostic = one("class Weapon:\n    x = 1\n")

      assert diagnostic.message =~ "no classes"
      assert diagnostic.doc == "entities.md"
    end
  end

  describe "calls that parse but don't exist" do
    test "print is named, with what to use instead" do
      diagnostic = one(~s|print("debug")\n|)

      assert diagnostic.message =~ "`print()` does not exist"
      assert diagnostic.hint =~ "character.msg"
    end

    test "range is named" do
      diagnostic = one("for i in range(10):\n    x = i\ndone\n")

      assert diagnostic.message =~ "`range()` does not exist"
    end

    test "pass is named" do
      diagnostic = one("if x:\n    pass\nendif\n")

      assert diagnostic.message =~ "`pass` does not exist"
    end

    test "a missing builtin is named individually" do
      assert one("best = max(scores)\n").message =~ "`max()` does not exist"
      assert one("items = sorted(things)\n").message =~ "`sorted()` does not exist"
    end

    test "builtins that do exist are not flagged" do
      assert [] == check(~s|total = len(items)\nname = str(total)\n|)
    end
  end

  describe "the colon in a dict literal" do
    test "a missing space after the colon is explained" do
      diagnostic = one(~s|d = {"a":1}\n|)

      assert diagnostic.message =~ "needs a space after the colon"
      assert diagnostic.hint =~ "15:00"
    end

    test "a later key is caught too" do
      assert one(~s|d = {"a": 1, "b":2}\n|).message =~ "space after the colon"
    end

    test "a properly spaced dict is left alone" do
      assert [] == check(~s|d = {"a": 1, "b": 2}\n|)
    end

    test "a set of times is left alone" do
      assert [] == check("times = {15:00, 16:00}\n")
    end
  end

  describe "prose is not code" do
    test "English words in a description are not reported" do
      code =
        ~s|Description("""\nA light filters from somewhere above.\nNot a class, for all that.\n""")|

      assert [] == check(code)
    end

    test "a comment mentioning lambda is not reported" do
      assert [] == check("# no lambda here\nx = 1\n")
    end

    test "a message quoting print() is not reported" do
      assert [] == check(~s|character.msg("print(x) is not real here")\n|)
    end

    test "a string containing a bracket does not confuse the scanner" do
      assert [] == check(~s|x = "a [b for c in d] string"\n|)
    end
  end

  describe "positions" do
    test "an unbalanced try is suggested when parsing stalls" do
      diagnostic = one("try:\n    x = 1\nexcept ValueError:\n    y = 2\n")

      assert diagnostic.hint =~ "endtry"
    end

    test "unparsable input reports where the parser gave up" do
      diagnostic = one("a = 1\nb = $$$\n")

      assert diagnostic.line == 2
      assert diagnostic.column == 1
    end

    test "the line option reports positions against the file" do
      diagnostic = one("x = 1\nf = lambda y: y\n", line: 40)

      assert diagnostic.line == 41
      assert diagnostic.source == "f = lambda y: y"
    end

    test "file and context are carried through" do
      diagnostic = one("import x\n", file: "worldlets/a.txt", context: "method run of !a!")

      assert diagnostic.file == "worldlets/a.txt"
      assert diagnostic.context == "method run of !a!"
    end
  end

  describe "format/1" do
    test "shows the location, the message, the source and the hint" do
      text =
        "if x:\n    y = 1\n"
        |> one(file: "worldlets/a.txt", context: "method run of !command/a!", line: 5)
        |> Diagnostic.format()

      assert text =~ "worldlets/a.txt:5"
      assert text =~ "in method run of !command/a!"
      assert text =~ "never closed"
      assert text =~ "if x:"
      assert text =~ "docs/scripting.md#conditions"
    end

    test "points a caret at the column when there is one" do
      text =
        "f = lambda x: x\n"
        |> one()
        |> Diagnostic.format()

      assert text =~ "^"
    end
  end
end
