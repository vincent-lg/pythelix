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

      assert {:ok, [entity]} = Pythelix.World.File.parse_file(path)
      assert entity.key == "object/thing"
      assert entity.attributes["parent"] == ~s("generic/object")
    end
  end
end
