defmodule Pythelix.World.CheckTest do
  use ExUnit.Case, async: true

  alias Pythelix.World.Check

  @moduletag :tmp_dir

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)

    path
  end

  defp run(path) do
    assert {:ok, result} = Check.run(path)
    result
  end

  describe "worldlets that parse" do
    test "a valid file reports no problem", %{tmp_dir: dir} do
      path =
        write(dir, "ok.txt", """
        !command/roll!
        parent = "generic/char_command"
        name = "roll"

        def run(character):
            result = random.randint(1, 6)
            if result == 1:
                character.msg("Ouch.")
            else:
                character.msg(f"You roll a {result}.")
            endif
        """)

      result = run(path)

      assert result.diagnostics == []
      assert result.entities == 1
    end

    test "comments outside a method are allowed", %{tmp_dir: dir} do
      # The first thing anyone writes in a new file is a line saying what it's
      # for — including above the first entity, where there is no method to
      # take it.
      path =
        write(dir, "commented.txt", """
        # Objects a scenario needs in place.

        !test/apple!
        # A comment between attributes, with an = sign in it.
        parent = "generic/object"
        singular = "a red apple"

        def taste(self, character):
            # A comment inside a method still belongs to the script.
            character.msg("Sweet.")
        """)

      result = run(path)

      assert result.diagnostics == []
      assert result.entities == 1
    end

    test "prose in a description is not mistaken for code", %{tmp_dir: dir} do
      path =
        write(dir, "room.txt", """
        !room/hall!
        parent = "generic/room"
        title = "A hall"
        description = Description(\"\"\"
        Light filters from somewhere above, in a class of its own,
        waiting for whoever comes in.
        \"\"\")
        """)

      assert run(path).diagnostics == []
    end
  end

  describe "worldlets that don't" do
    test "a missing endif is reported on its own line, in its own entity", %{tmp_dir: dir} do
      path =
        write(dir, "broken.txt", """
        !command/roll!
        parent = "generic/char_command"

        def run(character):
            if result == 1:
                character.msg("one")

        !command/who!
        parent = "generic/char_command"

        def run(character):
            character.msg("who")
        """)

      assert [diagnostic] = run(path).diagnostics

      # Line 5, not wherever the parser eventually gave up.
      assert diagnostic.line == 5
      assert diagnostic.context == "method run of !command/roll!"
      assert diagnostic.message =~ "never closed"
      assert diagnostic.hint =~ "endif"
    end

    test "every broken method is reported, not only the first", %{tmp_dir: dir} do
      path =
        write(dir, "two.txt", """
        !command/a!
        parent = "generic/char_command"

        def run(character):
            if x:
                character.msg("a")

        !command/b!
        parent = "generic/char_command"

        def run(character):
            names = [c.name for c in clients.active()]
        """)

      diagnostics = run(path).diagnostics

      assert length(diagnostics) == 2
      assert Enum.map(diagnostics, & &1.line) == [5, 12]

      assert Enum.map(diagnostics, & &1.context) == [
               "method run of !command/a!",
               "method run of !command/b!"
             ]
    end

    test "an assignment in a method body is not taken for an attribute", %{tmp_dir: dir} do
      path =
        write(dir, "assign.txt", """
        !command/a!
        parent = "generic/char_command"

        def run(character):
        count = 0
        if count == 0:
            character.msg("none")
        """)

      assert [diagnostic] = run(path).diagnostics

      # `count = 0` sits at column 0, but it belongs to the method: the unclosed
      # `if` below it must still be reported against the method.
      assert diagnostic.context == "method run of !command/a!"
      assert diagnostic.message =~ "never closed"
    end

    test "a problem inside an attribute value names the attribute", %{tmp_dir: dir} do
      path =
        write(dir, "attr.txt", """
        !object/thing!
        parent = "generic/object"
        tags = [t for t in others]
        """)

      assert [diagnostic] = run(path).diagnostics

      assert diagnostic.context == "attribute tags of !object/thing!"
      assert diagnostic.line == 3
      assert diagnostic.message =~ "comprehensions are not supported"
    end
  end

  describe "paths" do
    test "a directory is checked recursively", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "nested"))
      write(dir, "a.txt", "!object/a!\nparent = \"generic/object\"\n")
      write(dir, "nested/b.txt", "!object/b!\nparent = \"generic/object\"\n")

      result = run(dir)

      assert length(result.files) == 2
      assert result.entities == 2
      assert result.diagnostics == []
    end

    test "a path that doesn't exist reports no file", %{tmp_dir: dir} do
      assert :nofile == Check.run(Path.join(dir, "absent.txt"))
    end
  end
end
