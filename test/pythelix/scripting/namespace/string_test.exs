defmodule Pythelix.Scripting.Namespace.StringTest do
  @moduledoc """
  Module to test the string API.
  """

  use Pythelix.ScriptingCase

  describe "__contains__" do
    test "in is True" do
      value = expr_ok("'a' in 'mardi'")
      assert value == true
    end

    test "in is False" do
      value = expr_ok("'b' in 'test'")
      assert value == false
    end

    test "not in is True" do
      value = expr_ok("'y' not in 'boat'")
      assert value == true
    end

    test "not in is False" do
      value = expr_ok("'t' not in 'tart'")
      assert value == false
    end
  end

  describe "capitalize" do
    test "capitalize an ASCII string in lowercase" do
      script =
        run("""
        s = "hold".capitalize()
        """)

      assert Script.get_variable_value(script, "s") == "Hold"
    end

    test "capitalize an ASCII string in uppercase" do
      script =
        run("""
        s = "HOLD".capitalize()
        """)

      assert Script.get_variable_value(script, "s") == "Hold"
    end

    test "capitalize a NON-ASCII string in lowercase" do
      script =
        run("""
        s = "être et avoir".capitalize()
        """)

      assert Script.get_variable_value(script, "s") == "Être et avoir"
    end

    test "capitalize a non-ASCII string in uppercase" do
      script =
        run("""
        s = "ÊTRE ET AVOIR".capitalize()
        """)

      assert Script.get_variable_value(script, "s") == "Être et avoir"
    end
  end

  describe "center" do
    test "center an ASCII string with even alignment" do
      script =
        run("""
        s = "ok".center(6)
        """)

      assert Script.get_variable_value(script, "s") == "  ok  "
    end

    test "center an ASCII string with odd alignment" do
      script =
        run("""
        s = "ok".center(7)
        """)

      assert Script.get_variable_value(script, "s") == "   ok  "
    end

    test "center a non-ASCII string with even alignment" do
      script =
        run("""
        s = "hé".center(6)
        """)

      assert Script.get_variable_value(script, "s") == "  hé  "
    end

    test "center a non-ASCII string with odd alignment" do
      script =
        run("""
        s = "hé".center(7)
        """)

      assert Script.get_variable_value(script, "s") == "   hé  "
    end

    test "center an ASCII string with even alignment and a fill character" do
      script =
        run("""
        s = "ok".center(6, "-")
        """)

      assert Script.get_variable_value(script, "s") == "--ok--"
    end

    test "center an ASCII string with odd alignment and a fill character" do
      script =
        run("""
        s = "ok".center(7, ";")
        """)

      assert Script.get_variable_value(script, "s") == ";;;ok;;"
    end

    test "center a non-ASCII string with even alignment and a fill character" do
      script =
        run("""
        s = "hé".center(6, ".")
        """)

      assert Script.get_variable_value(script, "s") == "..hé.."
    end

    test "center a non-ASCII string with odd alignment and a fill character" do
      script =
        run("""
        s = "hé".center(7, "é")
        """)

      assert Script.get_variable_value(script, "s") == "éééhééé"
    end

    test "center returns original string when longer than width" do
      script =
        run("""
        s = "hello world".center(5)
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "center returns original string when equal to width" do
      script =
        run("""
        s = "hello".center(5)
        """)

      assert Script.get_variable_value(script, "s") == "hello"
    end
  end

  describe "endswith" do
    test "string ends with suffix" do
      script =
        run("""
        s = "hello world".endswith("world")
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string does not end with suffix" do
      script =
        run("""
        s = "hello world".endswith("hello")
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "endswith with start parameter" do
      script =
        run("""
        s = "hello world".endswith("lo", 3)
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "endswith with start and end parameters" do
      script =
        run("""
        s = "hello world".endswith("lo", 3, 5)
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "endswith empty string" do
      script =
        run("""
        s = "hello".endswith("")
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "find" do
    test "find existing substring" do
      script =
        run("""
        s = "hello world".find("world")
        """)

      assert Script.get_variable_value(script, "s") == 6
    end

    test "find non-existing substring" do
      script =
        run("""
        s = "hello world".find("xyz")
        """)

      assert Script.get_variable_value(script, "s") == -1
    end

    test "find with start parameter" do
      script =
        run("""
        s = "hello hello".find("hello", 1)
        """)

      assert Script.get_variable_value(script, "s") == 6
    end

    test "find with start and end parameters" do
      script =
        run("""
        s = "hello hello".find("hello", 1, 8)
        """)

      assert Script.get_variable_value(script, "s") == -1
    end

    test "find empty string" do
      script =
        run("""
        s = "hello".find("")
        """)

      assert Script.get_variable_value(script, "s") == 0
    end
  end

  describe "index" do
    test "index of existing substring" do
      script =
        run("""
        s = "hello world".index("world")
        """)

      assert Script.get_variable_value(script, "s") == 6
    end

    test "index raises error for non-existing substring" do
      traceback =
        expr_fail("""
        s = "hello world".index("xyz")
        """)

      assert traceback.exception == ValueError
    end

    test "index with start parameter" do
      script =
        run("""
        s = "hello hello".index("hello", 1)
        """)

      assert Script.get_variable_value(script, "s") == 6
    end
  end

  describe "isalnum" do
    test "alphanumeric string" do
      script =
        run("""
        s = "abc123".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "alphabetic string" do
      script =
        run("""
        s = "abcdef".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "numeric string" do
      script =
        run("""
        s = "123456".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with special characters" do
      script =
        run("""
        s = "abc123!".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "string with spaces" do
      script =
        run("""
        s = "abc 123".isalnum()
        """)

      assert Script.get_variable_value(script, "s") == false
    end
  end

  describe "isalpha" do
    test "alphabetic string" do
      script =
        run("""
        s = "abcdef".isalpha()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with numbers" do
      script =
        run("""
        s = "abc123".isalpha()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isalpha()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "non-ASCII alphabetic" do
      script =
        run("""
        s = "café".isalpha()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "isascii" do
    test "ASCII string" do
      script =
        run("""
        s = "hello".isascii()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "non-ASCII string" do
      script =
        run("""
        s = "café".isascii()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isascii()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "ASCII with special characters" do
      script =
        run("""
        s = "hello!@#".isascii()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "isdecimal" do
    test "decimal string" do
      script =
        run("""
        s = "12345".isdecimal()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with letters" do
      script =
        run("""
        s = "123a5".isdecimal()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isdecimal()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "string with decimal point" do
      script =
        run("""
        s = "123.45".isdecimal()
        """)

      assert Script.get_variable_value(script, "s") == false
    end
  end

  describe "isdigit" do
    test "digit string" do
      script =
        run("""
        s = "12345".isdigit()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with letters" do
      script =
        run("""
        s = "123a5".isdigit()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isdigit()
        """)

      assert Script.get_variable_value(script, "s") == false
    end
  end

  describe "isidentifier" do
    test "valid identifier" do
      script =
        run("""
        s = "variable_name".isidentifier()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "identifier starting with underscore" do
      script =
        run("""
        s = "_private".isidentifier()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "identifier starting with number" do
      script =
        run("""
        s = "2invalid".isidentifier()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "identifier with spaces" do
      script =
        run("""
        s = "not valid".isidentifier()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isidentifier()
        """)

      assert Script.get_variable_value(script, "s") == false
    end
  end

  describe "islower" do
    test "lowercase string" do
      script =
        run("""
        s = "hello".islower()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "uppercase string" do
      script =
        run("""
        s = "HELLO".islower()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "mixed case string" do
      script =
        run("""
        s = "Hello".islower()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "string with no cased characters" do
      script =
        run("""
        s = "123!@#".islower()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "lowercase with numbers" do
      script =
        run("""
        s = "hello123".islower()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "isnumeric" do
    test "numeric string" do
      script =
        run("""
        s = "12345".isnumeric()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with letters" do
      script =
        run("""
        s = "123a5".isnumeric()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isnumeric()
        """)

      assert Script.get_variable_value(script, "s") == false
    end
  end

  describe "isprintable" do
    test "printable string" do
      script =
        run("""
        s = "hello world!".isprintable()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "empty string" do
      script =
        run("""
        s = "".isprintable()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "isspace" do
    test "whitespace string" do
      script =
        run("""
        s = "   ".isspace()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string with text" do
      script =
        run("""
        s = "hello world".isspace()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".isspace()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "mixed whitespace" do
      script =
        run("""
        s = " \\n".isspace()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "istitle" do
    test "title case string" do
      script =
        run("""
        s = "Hello World".istitle()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "lowercase string" do
      script =
        run("""
        s = "hello world".istitle()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "uppercase string" do
      script =
        run("""
        s = "HELLO WORLD".istitle()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "mixed case string" do
      script =
        run("""
        s = "hELLo WoRLd".istitle()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "empty string" do
      script =
        run("""
        s = "".istitle()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "isupper" do
    test "uppercase string" do
      script =
        run("""
        s = "HELLO".isupper()
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "lowercase string" do
      script =
        run("""
        s = "hello".isupper()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "mixed case string" do
      script =
        run("""
        s = "Hello".isupper()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "string with no cased characters" do
      script =
        run("""
        s = "123!@#".isupper()
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "uppercase with numbers" do
      script =
        run("""
        s = "HELLO123".isupper()
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "join" do
    test "join list of strings" do
      script =
        run("""
        s = ", ".join(["a", "b", "c"])
        """)

      assert Script.get_variable_value(script, "s") == "a, b, c"
    end

    test "join empty list" do
      script =
        run("""
        s = ", ".join([])
        """)

      assert Script.get_variable_value(script, "s") == ""
    end

    test "join single item list" do
      script =
        run("""
        s = ", ".join(["hello"])
        """)

      assert Script.get_variable_value(script, "s") == "hello"
    end

    test "join with empty separator" do
      script =
        run("""
        s = "".join(["a", "b", "c"])
        """)

      assert Script.get_variable_value(script, "s") == "abc"
    end

    test "join with incorrect types" do
      traceback =
        expr_fail("""
        " ".join(["a", 1])
        """)

      assert traceback.exception == TypeError
    end
  end

  describe "ljust" do
    test "left-justify an ASCII string without fill characters" do
      script =
        run("""
        s = "ok".ljust(6)
        """)

      assert Script.get_variable_value(script, "s") == "ok    "
    end

    test "left-justify a non-ASCII string" do
      script =
        run("""
        s = "hé".ljust(6)
        """)

      assert Script.get_variable_value(script, "s") == "hé    "
    end

    test "left-justify an ASCII string with a fill character" do
      script =
        run("""
        s = "ok".ljust(6, "-")
        """)

      assert Script.get_variable_value(script, "s") == "ok----"
    end

    test "left-justify a non-ASCII string with a fill character" do
      script =
        run("""
        s = "hé".ljust(6, "é")
        """)

      assert Script.get_variable_value(script, "s") == "hééééé"
    end
  end

  describe "lower" do
    test "affectation of lower on ASCCII letters" do
      script =
        run("""
        s = "THIS".lower()
        """)

      assert Script.get_variable_value(script, "s") == "this"
    end

    test "a string with only uppercase ASCII letters" do
      script =
        run("""
        s = "THIS"
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == "this"
    end

    test "a string with ASCII uppercase and lowercase letters" do
      script =
        run("""
        s = "ThaT"
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == "that"
    end

    test "a string with ASCII uppercase and lowercase letters and other characters" do
      script =
        run("""
        s = " It SHould WorK="
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == " it should work="
    end

    test "a string with only uppercase non-ASCII letters" do
      script =
        run("""
        s = "OLÁ"
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == "olá"
    end

    test "a string with non-ASCII uppercase and lowercase letters" do
      script =
        run("""
        s = "ÉRic"
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == "éric"
    end

    test "a string with non-ASCII uppercase and lowercase letters and other characters" do
      script =
        run("""
        s = ' rÜCKSIcHTSLOS-'
        s = s.lower()
        """)

      assert Script.get_variable_value(script, "s") == " rücksichtslos-"
    end
  end

  describe "lstrip" do
    test "left-stripping spaces from ASCII characters" do
      script =
        run("""
        s = "  this ".lstrip()
        """)

      assert Script.get_variable_value(script, "s") == "this "
    end

    test "left-stripping one delimiter from ASCII characters" do
      script =
        run("""
        s = ";;this;".lstrip(";")
        """)

      assert Script.get_variable_value(script, "s") == "this;"
    end

    test "left-stripping delimiters from ASCII characters" do
      script =
        run("""
        s = ";-;this-;".lstrip("-;")
        """)

      assert Script.get_variable_value(script, "s") == "this-;"
    end

    test "left-stripping spaces from non-ASCII characters" do
      script =
        run("""
        s = "  ère ".lstrip()
        """)

      assert Script.get_variable_value(script, "s") == "ère "
    end

    test "stripping one delimiter from non-ASCII characters" do
      script =
        run("""
        s = ";;rêve;".lstrip(";")
        """)

      assert Script.get_variable_value(script, "s") == "rêve;"
    end

    test "left-stripping delimiters from non-ASCII characters" do
      script =
        run("""
        s = ";-;maïs-;".lstrip("-;")
        """)

      assert Script.get_variable_value(script, "s") == "maïs-;"
    end
  end

  describe "removeprefix" do
    test "remove existing prefix" do
      script =
        run("""
        s = "hello world".removeprefix("hello ")
        """)

      assert Script.get_variable_value(script, "s") == "world"
    end

    test "remove non-existing prefix" do
      script =
        run("""
        s = "hello world".removeprefix("goodbye ")
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "remove empty prefix" do
      script =
        run("""
        s = "hello world".removeprefix("")
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "remove entire string as prefix" do
      script =
        run("""
        s = "hello".removeprefix("hello")
        """)

      assert Script.get_variable_value(script, "s") == ""
    end
  end

  describe "removesuffix" do
    test "remove existing suffix" do
      script =
        run("""
        s = "hello world".removesuffix(" world")
        """)

      assert Script.get_variable_value(script, "s") == "hello"
    end

    test "remove non-existing suffix" do
      script =
        run("""
        s = "hello world".removesuffix(" goodbye")
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "remove empty suffix" do
      script =
        run("""
        s = "hello world".removesuffix("")
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "remove entire string as suffix" do
      script =
        run("""
        s = "hello".removesuffix("hello")
        """)

      assert Script.get_variable_value(script, "s") == ""
    end
  end

  describe "replace" do
    test "replace all occurrences" do
      script =
        run("""
        s = "hello world hello".replace("hello", "hi")
        """)

      assert Script.get_variable_value(script, "s") == "hi world hi"
    end

    test "replace with count limit" do
      script =
        run("""
        s = "hello world hello".replace("hello", "hi", 1)
        """)

      assert Script.get_variable_value(script, "s") == "hi world hello"
    end

    test "replace non-existing substring" do
      script =
        run("""
        s = "hello world".replace("xyz", "abc")
        """)

      assert Script.get_variable_value(script, "s") == "hello world"
    end

    test "replace with empty string" do
      script =
        run("""
        s = "hello world".replace("o", "")
        """)

      assert Script.get_variable_value(script, "s") == "hell wrld"
    end

    test "replace empty string" do
      script =
        run("""
        s = "hello".replace("", "x")
        """)

      assert Script.get_variable_value(script, "s") == "xhxexlxlxox"
    end
  end

  describe "rfind" do
    test "rfind existing substring" do
      script =
        run("""
        s = "hello world hello".rfind("hello")
        """)

      assert Script.get_variable_value(script, "s") == 12
    end

    test "rfind non-existing substring" do
      script =
        run("""
        s = "hello world".rfind("xyz")
        """)

      assert Script.get_variable_value(script, "s") == -1
    end

    test "rfind with start parameter" do
      script =
        run("""
        s = "hello world hello".rfind("hello", 1)
        """)

      assert Script.get_variable_value(script, "s") == 12
    end

    test "rfind single occurrence" do
      script =
        run("""
        s = "hello world".rfind("world")
        """)

      assert Script.get_variable_value(script, "s") == 6
    end
  end

  describe "rindex" do
    test "rindex of existing substring" do
      script =
        run("""
        s = "hello world hello".rindex("hello")
        """)

      assert Script.get_variable_value(script, "s") == 12
    end

    test "rindex raises error for non-existing substring" do
      traceback =
        expr_fail("""
        s = "hello world".rindex("xyz")
        """)

      assert traceback.exception == ValueError
    end
  end

  describe "rjust" do
    test "right-justify an ASCII string without fill characters" do
      script =
        run("""
        s = "ok".rjust(6)
        """)

      assert Script.get_variable_value(script, "s") == "    ok"
    end

    test "right-justify a non-ASCII string" do
      script =
        run("""
        s = "hé".rjust(6)
        """)

      assert Script.get_variable_value(script, "s") == "    hé"
    end

    test "right-justify an ASCII string with a fill character" do
      script =
        run("""
        s = "ok".rjust(6, "-")
        """)

      assert Script.get_variable_value(script, "s") == "----ok"
    end

    test "right-justify a non-ASCII string with a fill character" do
      script =
        run("""
        s = "hé".rjust(6, "é")
        """)

      assert Script.get_variable_value(script, "s") == "ééééhé"
    end
  end

  describe "rsplit" do
    test "rsplit with default separator" do
      script =
        run("""
        s = "hello world test".rsplit()
        """)

      assert Script.get_variable_value(script, "s") == ["hello", "world", "test"]
    end

    test "rsplit with custom separator" do
      script =
        run("""
        s = "a,b,c,d".rsplit(",")
        """)

      assert Script.get_variable_value(script, "s") == ["a", "b", "c", "d"]
    end

    test "rsplit with maxsplit" do
      script =
        run("""
        s = "a,b,c,d".rsplit(",", 2)
        """)

      assert Script.get_variable_value(script, "s") == ["a,b", "c", "d"]
    end

    test "rsplit empty string" do
      script =
        run("""
        s = "".rsplit()
        """)

      assert Script.get_variable_value(script, "s") == []
    end
  end

  describe "rstrip" do
    test "right-stripping spaces from ASCII characters" do
      script =
        run("""
        s = "  this ".rstrip()
        """)

      assert Script.get_variable_value(script, "s") == "  this"
    end

    test "right-stripping one delimiter from ASCII characters" do
      script =
        run("""
        s = ";;this;".rstrip(";")
        """)

      assert Script.get_variable_value(script, "s") == ";;this"
    end

    test "right-stripping delimiters from ASCII characters" do
      script =
        run("""
        s = ";-;this-;".rstrip("-;")
        """)

      assert Script.get_variable_value(script, "s") == ";-;this"
    end

    test "right-stripping spaces from non-ASCII characters" do
      script =
        run("""
        s = "  ère ".rstrip()
        """)

      assert Script.get_variable_value(script, "s") == "  ère"
    end

    test "right-stripping one delimiter from non-ASCII characters" do
      script =
        run("""
        s = ";;rêve;".rstrip(";")
        """)

      assert Script.get_variable_value(script, "s") == ";;rêve"
    end

    test "right-stripping delimiters from non-ASCII characters" do
      script =
        run("""
        s = ";-;maïs-;".rstrip("-;")
        """)

      assert Script.get_variable_value(script, "s") == ";-;maïs"
    end
  end

  describe "split" do
    test "split with default separator" do
      script =
        run("""
        s = "hello world test".split()
        """)

      assert Script.get_variable_value(script, "s") == ["hello", "world", "test"]
    end

    test "split with custom separator" do
      script =
        run("""
        s = "a,b,c,d".split(",")
        """)

      assert Script.get_variable_value(script, "s") == ["a", "b", "c", "d"]
    end

    test "split with maxsplit" do
      script =
        run("""
        s = "a,b,c,d".split(",", 2)
        """)

      assert Script.get_variable_value(script, "s") == ["a", "b", "c,d"]
    end

    test "split empty string" do
      script =
        run("""
        s = "".split()
        """)

      assert Script.get_variable_value(script, "s") == []
    end

    test "split with multiple spaces" do
      script =
        run("""
        s = "hello   world    test".split()
        """)

      assert Script.get_variable_value(script, "s") == ["hello", "world", "test"]
    end
  end

  describe "splitlines" do
    test "splitlines without keepends" do
      script =
        run("""
        s = "hello\\nworld\\ntest".splitlines()
        """)

      assert Script.get_variable_value(script, "s") == ["hello", "world", "test"]
    end

    test "splitlines with keepends" do
      script =
        run("""
        s = "hello\\nworld\\ntest".splitlines(True)
        """)

      assert Script.get_variable_value(script, "s") == ["hello\n", "world\n", "test"]
    end

    test "splitlines single line" do
      script =
        run("""
        s = "hello world".splitlines()
        """)

      assert Script.get_variable_value(script, "s") == ["hello world"]
    end

    test "splitlines empty string" do
      script =
        run("""
        s = "".splitlines()
        """)

      assert Script.get_variable_value(script, "s") == [""]
    end

    test "splitlines with only newlines" do
      script =
        run("""
        s = "\\n\\n".splitlines()
        """)

      assert Script.get_variable_value(script, "s") == ["", "", ""]
    end
  end

  describe "startswith" do
    test "string starts with prefix" do
      script =
        run("""
        s = "hello world".startswith("hello")
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "string does not start with prefix" do
      script =
        run("""
        s = "hello world".startswith("world")
        """)

      assert Script.get_variable_value(script, "s") == false
    end

    test "startswith with start parameter" do
      script =
        run("""
        s = "hello world".startswith("world", 6)
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "startswith with start and end parameters" do
      script =
        run("""
        s = "hello world".startswith("wor", 6, 9)
        """)

      assert Script.get_variable_value(script, "s") == true
    end

    test "startswith empty string" do
      script =
        run("""
        s = "hello".startswith("")
        """)

      assert Script.get_variable_value(script, "s") == true
    end
  end

  describe "strip" do
    test "stripping spaces from ASCII characters" do
      script =
        run("""
        s = "  this ".strip()
        """)

      assert Script.get_variable_value(script, "s") == "this"
    end

    test "stripping one delimiter from ASCII characters" do
      script =
        run("""
        s = ";;this;".strip(";")
        """)

      assert Script.get_variable_value(script, "s") == "this"
    end

    test "stripping delimiters from ASCII characters" do
      script =
        run("""
        s = ";-;this-;".strip("-;")
        """)

      assert Script.get_variable_value(script, "s") == "this"
    end

    test "stripping spaces from non-ASCII characters" do
      script =
        run("""
        s = "  ère ".strip()
        """)

      assert Script.get_variable_value(script, "s") == "ère"
    end

    test "stripping one delimiter from non-ASCII characters" do
      script =
        run("""
        s = ";;rêve;".strip(";")
        """)

      assert Script.get_variable_value(script, "s") == "rêve"
    end

    test "stripping delimiters from non-ASCII characters" do
      script =
        run("""
        s = ";-;maïs-;".strip("-;")
        """)

      assert Script.get_variable_value(script, "s") == "maïs"
    end
  end

  describe "title" do
    test "title-case an ASCII string in lowercase" do
      script =
        run("""
        s = "a christmas carol".title()
        """)

      assert Script.get_variable_value(script, "s") == "A Christmas Carol"
    end

    test "title-case an ASCII string in uppercase" do
      script =
        run("""
        s = "A CHRISTMAS CAROL".title()
        """)

      assert Script.get_variable_value(script, "s") == "A Christmas Carol"
    end

    test "title-case a NON-ASCII string in lowercase" do
      script =
        run("""
        s = "être et avoir".title()
        """)

      assert Script.get_variable_value(script, "s") == "Être Et Avoir"
    end

    test "title-case a non-ASCII string in uppercase" do
      script =
        run("""
        s = "ÊTRE ET AVOIR".title()
        """)

      assert Script.get_variable_value(script, "s") == "Être Et Avoir"
    end
  end

  describe "upper" do
    test "affectation of upper on ASCCII letters" do
      script =
        run("""
        s = "this".upper()
        """)

      assert Script.get_variable_value(script, "s") == "THIS"
    end

    test "a string with only lowercase ASCII letters" do
      script =
        run("""
        s = "this"
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == "THIS"
    end

    test "a string with ASCII uppercase and lowercase letters" do
      script =
        run("""
        s = "ThaT"
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == "THAT"
    end

    test "a string with ASCII uppercase and lowercase letters and other characters" do
      script =
        run("""
        s = " It SHould WorK="
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == " IT SHOULD WORK="
    end

    test "a string with only lowercase non-ASCII letters" do
      script =
        run("""
        s = "olá"
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == "OLÁ"
    end

    test "a string with non-ASCII uppercase and lowercase letters" do
      script =
        run("""
        s = "éRic"
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == "ÉRIC"
    end

    test "a string with non-ASCII uppercase and lowercase letters and other characters" do
      script =
        run("""
        s = ' rüCKSIcHTSLoS-'
        s = s.upper()
        """)

      assert Script.get_variable_value(script, "s") == " RÜCKSICHTSLOS-"
    end
  end
end
