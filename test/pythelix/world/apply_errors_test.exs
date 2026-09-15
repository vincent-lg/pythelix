defmodule Pythelix.World.ApplyErrorsTest do
  @moduledoc """
  Applying a worldlet that doesn't parse should explain itself in Pythello
  terms. These are the messages an administrator reads in the MUD client after
  `apply`, so they are the ones worth pinning down.
  """

  use Pythelix.DataCase, async: false

  @moduletag :tmp_dir

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)

    path
  end

  defp apply_error(path) do
    assert {:error, reason} = Pythelix.World.apply(path)

    reason
  end

  describe "a method that doesn't parse" do
    test "reports the rule instead of a stacktrace", %{tmp_dir: dir} do
      path =
        write(dir, "broken.txt", """
        !object/gadget!
        parent = "generic/object"

        def describe(self):
            names = [c.name for c in self.contents]
            return names
        """)

      reason = apply_error(path)

      assert reason =~ "list comprehensions are not supported"
      assert reason =~ "method describe of !object/gadget!"
      assert reason =~ "broken.txt:5"
      refute reason =~ "Elixir."
      refute reason =~ "__STACKTRACE__"
    end

    test "an unclosed block names the keyword that closes it", %{tmp_dir: dir} do
      path =
        write(dir, "unclosed.txt", """
        !object/gadget!
        parent = "generic/object"

        def describe(self):
            if self.broken:
                return "yes"
        """)

      reason = apply_error(path)

      assert reason =~ "never closed"
      assert reason =~ "endif"
      refute reason =~ "MatchError"
    end
  end

  describe "an attribute that doesn't parse" do
    test "names the attribute rather than raising a match error", %{tmp_dir: dir} do
      path =
        write(dir, "attr.txt", """
        !object/gadget!
        parent = "generic/object"
        tags = [t for t in others]
        """)

      reason = apply_error(path)

      assert reason =~ "comprehensions are not supported"
      assert reason =~ "attribute tags of !object/gadget!"
      refute reason =~ "MatchError"
    end
  end

  describe "failures the checker can't explain" do
    test "keep the original message", %{tmp_dir: dir} do
      # Valid Pythello throughout, but the parent doesn't exist: nothing for the
      # checker to find, so whatever the engine said must survive.
      path =
        write(dir, "cycle.txt", """
        !object/a!
        parent = "object/b"

        !object/b!
        parent = "object/a"
        """)

      reason = apply_error(path)

      assert is_binary(reason)
      assert reason =~ "circle"
      assert reason =~ "parent"
    end
  end

  describe "worldlets that do parse" do
    test "still apply", %{tmp_dir: dir} do
      path =
        write(dir, "ok.txt", """
        !object/gadget!
        parent = "generic/object"
        singular = "a gadget"

        def describe(self):
            names = []
            for content in self.contents:
                names.append(content)
            done

            return names
        """)

      Pythelix.World.apply(:static)

      assert {:ok, _path, number} = Pythelix.World.apply(path)
      assert number > 0
    end
  end
end
