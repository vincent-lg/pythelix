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
