defmodule Pythelix.World.LayersTest do
  @moduledoc """
  An entity declared again with the same key is merged into the earlier
  declaration, attribute by attribute and method by method, the later one
  winning. Plugins rest on this: a game adjusts a plugin's entity by redeclaring
  it and changing only what needs to change.
  """

  use Pythelix.DataCase, async: false

  @moduletag :tmp_dir

  alias Pythelix.{Record, World}
  alias Pythelix.World.Sources

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)

    path
  end

  defp apply!(path) do
    assert {:ok, _path, _number, _notices} = World.apply(path)
  end

  defp attribute(key, name), do: key |> Record.get_entity() |> Record.get_attribute(name)

  defp parent_key(key) do
    parent_id = key |> Record.get_entity() |> Map.fetch!(:parent_id)

    Record.get_entity(parent_id).key
  end

  describe "overriding across files" do
    test "an override that omits the parent keeps it", %{tmp_dir: dir} do
      # `z_override` sorts after the declaration, and `a_parent` is only reached
      # through the child: losing the dependency would create the child first,
      # without a parent.
      write(dir, "a_child.txt", """
      !test/child!
      parent = "test/zz_parent"
      title = "original"
      """)

      write(dir, "m_parent.txt", """
      !test/zz_parent!
      inherited = "from the parent"
      """)

      write(dir, "z_override.txt", """
      !test/child!
      title = "overridden"
      """)

      apply!(dir)

      assert parent_key("test/child") == "test/zz_parent"
      assert attribute("test/child", "title") == "overridden"
      assert attribute("test/child", "inherited") == "from the parent"
    end

    test "attributes and methods not mentioned are kept", %{tmp_dir: dir} do
      write(dir, "a.txt", """
      !test/thing!
      one = 1
      two = 2

      def first(self):
          return "first"

      def second(self):
          return "second"
      """)

      write(dir, "b.txt", """
      !test/thing!
      two = 22

      def second(self):
          return "overridden"
      """)

      apply!(dir)

      assert attribute("test/thing", "one") == 1
      assert attribute("test/thing", "two") == 22

      thing = Record.get_entity("test/thing")
      assert %{code: "    return \"first\"" <> _} = Record.get_method(thing, "first")
      assert %{code: "    return \"overridden\"" <> _} = Record.get_method(thing, "second")
    end

    test "changing the parent re-parents an entity that already exists", %{tmp_dir: dir} do
      first =
        write(dir, "first.txt", """
        !test/old_parent!
        !test/new_parent!
        !test/child!
        parent = "test/old_parent"
        """)

      apply!(first)
      assert parent_key("test/child") == "test/old_parent"

      second =
        write(dir, "second.txt", """
        !test/child!
        parent = "test/new_parent"
        """)

      apply!(second)
      assert parent_key("test/child") == "test/new_parent"

      assert Record.has_parent?(
               Record.get_entity("test/child"),
               Record.get_entity("test/new_parent")
             )
    end

    test "parent = None detaches an entity from its parent", %{tmp_dir: dir} do
      first =
        write(dir, "first.txt", """
        !test/old_parent!
        inherited = "from the parent"
        !test/child!
        parent = "test/old_parent"
        """)

      apply!(first)
      assert attribute("test/child", "inherited") == "from the parent"

      second =
        write(dir, "second.txt", """
        !test/child!
        parent = None
        """)

      apply!(second)
      assert Record.get_entity("test/child").parent_id == nil
      assert attribute("test/child", "inherited") == nil
    end

    test "a cycle made by overriding parents is reported", %{tmp_dir: dir} do
      write(dir, "a.txt", """
      !test/a!
      parent = "test/b"
      """)

      write(dir, "b.txt", """
      !test/b!
      !test/c!
      """)

      write(dir, "c.txt", """
      !test/b!
      parent = "test/a"
      """)

      assert {:error, reason} = World.apply(dir)
      assert reason =~ "depend on each other"
    end
  end

  describe "overriding within one file" do
    test "the last declaration wins, as it does across files", %{tmp_dir: dir} do
      path =
        write(dir, "twice.txt", """
        !test/thing!
        title = "first"

        !test/thing!
        title = "second"
        """)

      apply!(path)

      assert attribute("test/thing", "title") == "second"
    end
  end

  describe "where a definition comes from" do
    test "each method remembers its own file and line", %{tmp_dir: dir} do
      first =
        write(dir, "a.txt", """
        !test/thing!

        def from_a(self):
            return 1
        """)

      second =
        write(dir, "b.txt", """
        # A comment, so that the line numbers differ.
        # And another.

        !test/thing!

        def from_b(self):
            return 2
        """)

      apply!(dir)

      thing = Record.get_entity("test/thing")
      from_a = Record.get_method(thing, "from_a")
      from_b = Record.get_method(thing, "from_b")

      assert from_a.file == Pythelix.Paths.relative(first)
      assert from_a.line == 4
      assert from_b.file == Pythelix.Paths.relative(second)
      assert from_b.line == 7
    end
  end

  describe "a partial apply" do
    test "does not undo an override of a built-in entity", %{tmp_dir: dir} do
      write(dir, "world/menus.txt", """
      !generic/menu!
      prompt = "overridden"
      """)

      apply!(Path.join(dir, "world"))
      assert attribute("generic/menu", "prompt") == "overridden"

      other =
        write(dir, "other.txt", """
        !test/unrelated!
        """)

      apply!(other)
      assert attribute("generic/menu", "prompt") == "overridden"
    end

    test "still brings the built-ins into an empty world", %{tmp_dir: dir} do
      path =
        write(dir, "lonely.txt", """
        !test/lonely!
        """)

      apply!(path)

      assert Record.get_entity("generic/menu")
      assert Record.get_entity("menu/game")
    end
  end

  describe "sources" do
    setup %{tmp_dir: dir} do
      worldlets = Path.join(dir, "worldlets")
      previous = Application.get_env(:pythelix, :worldlets_path)
      Application.put_env(:pythelix, :worldlets_path, worldlets)
      on_exit(fn -> Application.put_env(:pythelix, :worldlets_path, previous) end)

      {:ok, worldlets: worldlets}
    end

    test "a path that doesn't exist has no source", %{tmp_dir: dir} do
      assert Sources.files(Path.join(dir, "absent")) == :nofile
    end

    test "a missing worldlets directory has no source" do
      assert Sources.files(:all) == :nofile
      assert World.apply(:all) == :nofile
    end

    test "applying, checking and listing agree", %{worldlets: worldlets} do
      write(worldlets, "a.txt", "!test/a!\n")
      write(worldlets, "sub/b.txt", "!test/b!\n")

      assert {:ok, files} = Sources.files(:all)
      assert Enum.map(files, &Path.basename/1) == ["a.txt", "b.txt"]

      assert {:ok, result} = World.Check.run(:all)
      assert length(result.files) == 2

      apply!(:all)
      assert Record.get_entity("test/a")
      assert Record.get_entity("test/b")
    end
  end
end
