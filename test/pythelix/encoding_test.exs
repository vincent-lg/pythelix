defmodule Pythelix.EncodingTest do
  @moduledoc """
  Builders write worldlets and scenarios in a text editor, often on Windows.
  Neither a CRLF line ending nor a Latin-1 accent should ever be the reason a
  file doesn't work.
  """

  use ExUnit.Case, async: false

  alias Pythelix.Encoding

  @moduletag :tmp_dir

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)

    path
  end

  describe "line endings" do
    test "CRLF becomes LF" do
      assert Encoding.normalize_newlines("a\r\nb\r\n") == "a\nb\n"
    end

    test "a lone CR becomes LF" do
      assert Encoding.normalize_newlines("a\rb") == "a\nb"
    end

    test "LF is left alone" do
      assert Encoding.normalize_newlines("a\nb\n") == "a\nb\n"
    end

    test "a file saved on Windows reads as if it weren't", %{tmp_dir: dir} do
      path = write(dir, "crlf.txt", "first\r\nsecond\r\n")

      assert Encoding.read_file!(path) == "first\nsecond\n"
    end
  end

  describe "encodings" do
    test "UTF-8 is read as UTF-8" do
      assert Encoding.decode("café") == "café"
    end

    test "a byte order mark is not part of the first line" do
      assert Encoding.decode("﻿title") == "title"
    end

    test "Latin-1 bytes are decoded rather than left broken" do
      # "café" in ISO-8859-15: the é is a single byte, invalid on its own as UTF-8.
      latin1 = <<99, 97, 102, 233>>

      refute String.valid?(latin1)

      Application.put_env(:pythelix, :default_encoding, "iso-8859-15")
      on_exit(fn -> Application.put_env(:pythelix, :default_encoding, "utf-8") end)

      decoded = Encoding.decode(latin1)

      assert String.valid?(decoded)
      assert decoded == "café"
    end

    test "valid UTF-8 wins over the configured encoding" do
      # Guessing against the evidence would corrupt a correct file.
      Application.put_env(:pythelix, :default_encoding, "iso-8859-15")
      on_exit(fn -> Application.put_env(:pythelix, :default_encoding, "utf-8") end)

      assert Encoding.decode("café") == "café"
    end

    test "WORLDLETS_ENCODING, when set, is what files fall back to" do
      # The players may well use one encoding and the builders' editors
      # another: the file setting wins over the players' default.
      Application.put_env(:pythelix, :default_encoding, "utf-8")
      Application.put_env(:pythelix, :worldlets_encoding, "iso-8859-15")
      on_exit(fn -> Application.delete_env(:pythelix, :worldlets_encoding) end)

      # The euro sign is 0xA4 in ISO-8859-15 and a currency sign in Latin-1.
      assert Encoding.decode_with(<<164>>) == {"€", "iso-8859-15"}
    end

    test "without WORLDLETS_ENCODING, files fall back to the players' encoding" do
      Application.put_env(:pythelix, :default_encoding, "cp1252")
      Application.delete_env(:pythelix, :worldlets_encoding)
      on_exit(fn -> Application.put_env(:pythelix, :default_encoding, "utf-8") end)

      assert Encoding.fallback_encoding() == "cp1252"
      assert Encoding.decode_with(<<128>>) == {"€", "cp1252"}
    end

    test "the decision is made per file", %{tmp_dir: dir} do
      Application.put_env(:pythelix, :worldlets_encoding, "cp1252")
      on_exit(fn -> Application.delete_env(:pythelix, :worldlets_encoding) end)

      utf8 = write(dir, "utf8.txt", "café\n")
      cp1252 = write(dir, "cp1252.txt", "caf" <> <<233>> <> "\n")

      assert Encoding.read_file(utf8) == {"café\n", "utf-8"}
      assert Encoding.read_file(cp1252) == {"café\n", "cp1252"}
    end
  end

  describe "files builders actually write" do
    test "a scenario saved with CRLF plays", %{tmp_dir: dir} do
      path =
        write(
          dir,
          "windows.txt",
          "given Alice in !room/bakery!\r\n\r\nAlice> look\r\nAlice sees \"bakery\"\r\n"
        )

      assert {:ok, scenario} = Pythelix.Scenario.parse_file(path)
      assert Enum.map(scenario.steps, & &1.kind) == [:given, :input, :sees]

      # A stray carriage return here would make every comparison fail for a
      # reason nobody can see on screen.
      assert Enum.map(scenario.steps, & &1.text) == [
               "!room/bakery!",
               "look",
               "bakery"
             ]
    end

    test "a worldlet saved with CRLF applies", %{tmp_dir: dir} do
      path =
        write(
          dir,
          "crlf.txt",
          "!object/thing!\r\nparent = \"generic/object\"\r\nsingular = \"a thing\"\r\n"
        )

      assert {:ok, [entity], []} = Pythelix.World.File.parse_file(path)
      assert entity.key == "object/thing"
      assert entity.attributes["parent"] == ~s("generic/object")
    end

    test "a worldlet saved in CP1252 applies, and the builder is told", %{tmp_dir: dir} do
      Application.put_env(:pythelix, :worldlets_encoding, "cp1252")
      on_exit(fn -> Application.delete_env(:pythelix, :worldlets_encoding) end)

      path =
        write(
          dir,
          "cp1252.txt",
          "!object/thing!\nparent = \"generic/object\"\nsingular = \"un d" <> <<233>> <> "\"\n"
        )

      assert {:ok, [entity], [notice]} = Pythelix.World.File.parse_file(path)
      assert entity.attributes["singular"] == ~s("un dé")
      assert notice =~ "cp1252.txt is not UTF-8 and was read as cp1252"
      assert notice =~ "Save it as UTF-8"
    end

    test "a scenario saved in CP1252 parses, and says so", %{tmp_dir: dir} do
      Application.put_env(:pythelix, :worldlets_encoding, "cp1252")
      on_exit(fn -> Application.delete_env(:pythelix, :worldlets_encoding) end)

      path =
        write(
          dir,
          "old.txt",
          "given Alice in !room/bakery!\n\nAlice> look\nAlice sees \"d" <> <<233>> <> "\"\n"
        )

      assert {:ok, scenario} = Pythelix.Scenario.parse_file(path)
      assert [%{text: "dé"}] = Enum.filter(scenario.steps, &(&1.kind == :sees))
      assert [notice] = scenario.notices
      assert notice =~ "old.txt is not UTF-8 and was read as cp1252"
    end

    test "a UTF-8 scenario has nothing to say", %{tmp_dir: dir} do
      path = write(dir, "fine.txt", "given Alice in !room/bakery!\n")

      assert {:ok, %{notices: []}} = Pythelix.Scenario.parse_file(path)
    end

    test "the checker passes the notice on", %{tmp_dir: dir} do
      Application.put_env(:pythelix, :worldlets_encoding, "cp1252")
      on_exit(fn -> Application.delete_env(:pythelix, :worldlets_encoding) end)

      write(dir, "fine.txt", "!object/fine!\nsingular = \"fine\"\n")
      write(dir, "old.txt", "!object/old!\nsingular = \"d" <> <<233>> <> "\"\n")

      assert {:ok, result} = Pythelix.World.Check.run(dir)
      assert result.diagnostics == []
      assert result.entities == 2
      assert [notice] = result.notices
      assert notice =~ "old.txt is not UTF-8"
    end
  end
end
