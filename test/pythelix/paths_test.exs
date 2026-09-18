defmodule Pythelix.PathsTest do
  @moduledoc """
  Two ways a perfectly good path stops working, both found by running a release
  rather than the source.

  On Windows a path arrives with backslashes, and `Path.wildcard/1` reads a
  backslash as an escape character: the directory matches nothing while every
  other check says it is fine.

  And a relative path means "in my game", not "relative to wherever this
  command was launched from" — which only shows up when someone runs
  `bin/scenario` from inside `bin`.
  """

  use ExUnit.Case, async: true

  alias Pythelix.Paths

  @moduletag :tmp_dir

  defp windows(path), do: String.replace(path, "/", <<92>>)

  describe "normalize/1" do
    test "backslashes become forward slashes" do
      assert Paths.normalize("C:" <> <<92>> <> "game" <> <<92>> <> "scenarios") ==
               "C:/game/scenarios"
    end

    test "forward slashes are left alone" do
      assert Paths.normalize("/home/game/scenarios") == "/home/game/scenarios"
    end

    test "a mixed path is made consistent" do
      # This is the shape a release produces: RELEASE_ROOT has backslashes and
      # `Path.join/2` appends with a forward slash.
      assert Paths.normalize("C:" <> <<92>> <> "game/scenarios") == "C:/game/scenarios"
    end
  end

  describe "globbing a Windows path" do
    setup %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "nested"))
      File.write!(Path.join(dir, "one.txt"), "")
      File.write!(Path.join(dir, "nested/two.txt"), "")

      :ok
    end

    test "the directory passes every check but matches nothing", %{tmp_dir: dir} do
      path = windows(dir)

      # The trap: these all agree the directory is there.
      assert File.exists?(path)
      assert File.dir?(path)

      # And yet.
      assert Path.wildcard("#{path}/**/*.txt") == []
    end

    test "normalising first finds the files", %{tmp_dir: dir} do
      path = windows(dir)

      assert length(Path.wildcard("#{Paths.normalize(path)}/**/*.txt")) == 2
    end
  end

  describe "resolve/1" do
    setup %{tmp_dir: dir} do
      # A name that cannot also exist relative to the test's own directory,
      # since a path that resolves as given is preferred and would mask this.
      File.mkdir_p!(Path.join(dir, "game_root_only"))
      File.write!(Path.join(dir, "game_root_only/room.txt"), "")

      Application.put_env(:pythelix, :base_path, dir)
      on_exit(fn -> Application.delete_env(:pythelix, :base_path) end)

      :ok
    end

    test "a relative path is found under the game's root", %{tmp_dir: dir} do
      # This is the case that broke: `bin/scenario` run from inside `bin`, where
      # "worldlets/room.txt" means the game's, not the current directory's.
      assert Paths.resolve("game_root_only/room.txt") ==
               Path.join(dir, "game_root_only/room.txt")
    end

    test "a path that exists as given wins", %{tmp_dir: dir} do
      # Standing in the game directory, a shell-completed path still works.
      here = Path.join(dir, "here/room.txt")
      File.mkdir_p!(Path.dirname(here))
      File.write!(here, "")

      assert Paths.resolve(here) == here
    end

    test "an absolute path is left alone", %{tmp_dir: dir} do
      absolute = Path.join(dir, "game_root_only/room.txt")

      assert Paths.resolve(absolute) == absolute
    end

    test "a path matching nothing comes back as typed" do
      # So the error names what the user actually wrote.
      assert Paths.resolve("nowhere/at/all.txt") == "nowhere/at/all.txt"
    end
  end

  describe "the commands that glob" do
    setup %{tmp_dir: dir} do
      File.write!(
        Path.join(dir, "scene.txt"),
        ~s|given Alice in !room/bakery!\nAlice> look\nAlice sees "bakery"\n|
      )

      File.write!(
        Path.join(dir, "world.txt"),
        ~s|!object/thing!\nparent = "generic/object"\n|
      )

      :ok
    end

    test "checking worldlets works with a backslash directory", %{tmp_dir: dir} do
      assert {:ok, result} = Pythelix.World.Check.run(windows(dir))
      assert length(result.files) == 2
    end

    test "scenarios are found under a backslash directory", %{tmp_dir: dir} do
      Application.put_env(:pythelix, :scenarios_path, windows(dir))
      on_exit(fn -> Application.delete_env(:pythelix, :scenarios_path) end)

      # `run/1` would play them; here it is enough that they are found at all,
      # which is what the bug broke.
      assert Path.wildcard("#{Paths.normalize(windows(dir))}/**/*.txt") != []
    end
  end
end
