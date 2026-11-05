defmodule Pythelix.Plugin.IntegrityTest do
  @moduledoc """
  A lock file records what was installed. A plugin edited in place gets reported,
  because the edits would be lost when it is updated, and the commands that would
  destroy something refuse to.
  """

  use Pythelix.DataCase, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  alias Pythelix.{Plugin, Record, World}
  alias Pythelix.Plugin.{Integrity, Lock, TreeHash}
  alias Pythelix.Task.Plugin, as: Command
  alias Pythelix.World.Check

  setup %{tmp_dir: dir} do
    settings = [
      base_path: dir,
      plugins_path: Path.join(dir, "plugins"),
      worldlets_path: Path.join(dir, "worldlets"),
      scenarios_path: Path.join(dir, "scenarios")
    ]

    previous = for {key, _} <- settings, do: {key, Application.get_env(:pythelix, key)}
    Application.put_all_env(pythelix: settings)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:pythelix, key)
        {key, value} -> Application.put_env(:pythelix, key, value)
      end)
    end)

    :ok
  end

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)

    path
  end

  defp plugin(dir, key, opts \\ []) do
    write(dir, "plugins/#{key}/plugin.txt", """
    !plugin/#{key}!
    parent = "generic/plugin"
    version = "1.0.0"
    depends = #{Keyword.get(opts, :depends, "{}")}
    """)

    write(dir, "plugins/#{key}/worldlets/room.txt", """
    !#{key}/room!
    title = "A Room"
    """)

    Plugin.path(key)
  end

  # Install a plugin as far as the lock file can tell.
  defp lock(key) do
    hash = TreeHash.compute(Plugin.path(key))

    :ok =
      Lock.put(key, %{
        version: "1.0.0",
        source: "https://example.com/#{key}.tar.gz",
        archive_hash: "abc",
        tree_hash: hash.tree,
        files: hash.files
      })
  end

  defp command(args) do
    {result, output} = with_io(fn -> Command.run(args) end)

    {result, output}
  end

  describe "the tree hash" do
    test "doesn't depend on line endings", %{tmp_dir: dir} do
      write(dir, "lf/a.txt", "one\ntwo\n")
      write(dir, "crlf/a.txt", "one\r\ntwo\r\n")
      write(dir, "cr/a.txt", "one\rtwo\r")

      lf = TreeHash.compute(Path.join(dir, "lf"))

      assert lf == TreeHash.compute(Path.join(dir, "crlf"))
      assert lf == TreeHash.compute(Path.join(dir, "cr"))
    end

    test "changes with content, with names, and with a new file", %{tmp_dir: dir} do
      write(dir, "a/a.txt", "one\n")
      write(dir, "b/a.txt", "two\n")
      write(dir, "c/b.txt", "one\n")
      write(dir, "d/a.txt", "one\n")
      write(dir, "d/b.txt", "two\n")

      hashes = for name <- ["a", "b", "c", "d"], do: TreeHash.compute(Path.join(dir, name)).tree

      assert hashes == Enum.uniq(hashes)
    end

    test "doesn't depend on where the directory is", %{tmp_dir: dir} do
      write(dir, "here/sub/a.txt", "one\n")
      write(dir, "there/far/away/sub/a.txt", "one\n")

      assert TreeHash.compute(Path.join(dir, "here")) ==
               TreeHash.compute(Path.join(dir, "there/far/away"))
    end

    test "uses forward slashes and ignores other files", %{tmp_dir: dir} do
      write(dir, "a/sub/a.txt", "one\n")
      write(dir, "a/sub/Thumbs.db", "junk")
      write(dir, "a/.DS_Store", "junk")

      assert %{files: files} = TreeHash.compute(Path.join(dir, "a"))
      assert Map.keys(files) == ["sub/a.txt"]
    end

    test "says what differs" do
      assert TreeHash.changes(%{"a" => "1", "b" => "2", "c" => "3"}, %{
               "a" => "1",
               "b" => "x",
               "d" => "4"
             }) == [{:changed, "b"}, {:removed, "c"}, {:added, "d"}]
    end
  end

  describe "the lock file" do
    test "no file means nothing is locked" do
      assert Lock.read() == {:ok, %{}}
    end

    test "keeps what it was given, sorted", %{tmp_dir: dir} do
      plugin(dir, "zulu")
      plugin(dir, "alpha")
      lock("zulu")
      lock("alpha")

      assert {:ok, %{"alpha" => alpha, "zulu" => _}} = Lock.read()
      assert alpha.version == "1.0.0"
      assert alpha.source == "https://example.com/alpha.tar.gz"
      assert Map.has_key?(alpha.files, "plugin.txt")

      text = File.read!(Path.join(dir, "plugins.lock"))
      assert :binary.match(text, "alpha") < :binary.match(text, "zulu")
    end

    test "goes away with the last plugin", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      assert :ok = Lock.delete("rooms")

      refute File.exists?(Path.join(dir, "plugins.lock"))
    end

    test "something unreadable is said to be", %{tmp_dir: dir} do
      write(dir, "plugins.lock", "{not json")

      assert {:error, reason} = Lock.read()
      assert reason =~ "plugins.lock"

      write(dir, "plugins.lock", ~s({"plugins": {"a": {"version": 3}}}))
      assert {:error, _} = Lock.read()
    end
  end

  describe "the status of a plugin" do
    test "no lock entry means local, whatever it contains", %{tmp_dir: dir} do
      plugin(dir, "rooms")

      assert Integrity.status("rooms", nil) == :local
      assert Integrity.notices() == []
    end

    test "untouched means intact", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")

      {:ok, %{"rooms" => entry}} = Lock.read()

      assert Integrity.status("rooms", entry) == :intact
      assert Integrity.notices() == []
    end

    test "changing line endings doesn't count as a change", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")

      room = Path.join(dir, "plugins/rooms/worldlets/room.txt")
      File.write!(room, String.replace(File.read!(room), "\n", "\r\n"))

      assert Integrity.notices() == []
    end

    test "an edit is reported, naming the files", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")

      write(dir, "plugins/rooms/worldlets/room.txt", "!rooms/room!\ntitle = \"Edited\"\n")
      write(dir, "plugins/rooms/worldlets/new.txt", "!rooms/new!\n")
      File.rm!(Path.join(dir, "plugins/rooms/plugin.txt"))

      {:ok, %{"rooms" => entry}} = Lock.read()

      assert {:modified, changes} = Integrity.status("rooms", entry)

      assert changes == [
               {:removed, "plugin.txt"},
               {:added, "worldlets/new.txt"},
               {:changed, "worldlets/room.txt"}
             ]
    end

    test "a directory gone is reported", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      File.rm_rf!(Plugin.path("rooms"))

      assert [notice] = Integrity.notices()
      assert notice =~ "directory is gone"
    end
  end

  describe "reporting a modified plugin" do
    setup %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      write(dir, "plugins/rooms/worldlets/room.txt", "!rooms/room!\ntitle = \"Edited\"\n")

      :ok
    end

    test "applying says so, and still applies" do
      assert {:ok, _, _, [notice]} = World.apply(:all)

      assert notice =~ "Plugin rooms was modified"
      assert notice =~ Pythelix.Paths.display("worldlets/room.txt")
      assert notice =~ "docs/plugins.md"
      assert notice =~ "plugin eject rooms"

      assert Record.get_attribute(Record.get_entity("rooms/room"), "title") == "Edited"
    end

    test "checking says so, without calling it a problem" do
      assert {:ok, result} = Check.run(:all)

      assert result.diagnostics == []
      assert [notice] = result.notices
      assert notice =~ "Plugin rooms was modified"
    end

    test "a plugin's isolated world doesn't care" do
      assert {:ok, _, _, []} = World.apply({:plugin, "rooms"})
    end

    test "a boot logs it" do
      Application.put_env(:pythelix, :worldlets, true)
      on_exit(fn -> Application.put_env(:pythelix, :worldlets, false) end)

      log = ExUnit.CaptureLog.capture_log(fn -> World.init() end)

      assert log =~ "Plugin rooms was modified"
    end
  end

  describe "plugin list" do
    test "shows each plugin's state", %{tmp_dir: dir} do
      plugin(dir, "installed")
      lock("installed")
      plugin(dir, "edited")
      lock("edited")
      write(dir, "plugins/edited/worldlets/room.txt", "!edited/room!\n")
      plugin(dir, "mine")

      assert {:ok, output} = command(["list"])

      assert output =~ "installed 1.0.0: installed"
      assert output =~ "edited 1.0.0: installed, MODIFIED"
      assert output =~ "mine 1.0.0: local"
    end

    test "says when there is nothing" do
      assert {:ok, output} = command(["list"])
      assert output =~ "No plugin is installed"
    end
  end

  describe "plugin verify" do
    test "passes when everything is as installed", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      plugin(dir, "mine")

      assert {:ok, output} = command(["verify"])
      assert output =~ "rooms: as installed"

      assert {:ok, output} = command(["verify", "mine"])
      assert output =~ "local"
    end

    test "fails on a modified plugin, naming the files", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      write(dir, "plugins/rooms/worldlets/room.txt", "!rooms/room!\n")

      assert {:error, output} = command(["verify"])
      assert output =~ "MODIFIED"
      assert output =~ Pythelix.Paths.display("worldlets/room.txt")
    end

    test "fails on a plugin that isn't there" do
      assert {:error, output} = command(["verify", "absent"])
      assert output =~ "no such plugin"
    end
  end

  describe "plugin remove" do
    test "deletes the directory and the lock entry", %{tmp_dir: dir} do
      directory = plugin(dir, "rooms")
      lock("rooms")

      assert {:ok, output} = command(["remove", "rooms"])
      assert output =~ "bin/apply"

      refute File.exists?(directory)
      assert Lock.read() == {:ok, %{}}
    end

    test "leaves the data in the database", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      write(dir, "worldlets/game.txt", "!game/room!
")
      {:ok, _, _, _} = World.apply(:all)

      assert {:ok, _} = command(["remove", "rooms"])
      {:ok, _, _, _} = World.apply(:all)

      assert Record.get_entity("rooms/room")
    end

    test "refuses when another plugin depends on it", %{tmp_dir: dir} do
      directory = plugin(dir, "rooms")
      lock("rooms")
      plugin(dir, "exits", depends: ~s({"rooms": "*"}))

      assert {:error, output} = command(["remove", "rooms", "-f"])
      assert output =~ "exits depend on it"
      assert File.exists?(directory)
    end

    test "refuses to lose edits, unless forced", %{tmp_dir: dir} do
      directory = plugin(dir, "rooms")
      lock("rooms")
      write(dir, "plugins/rooms/worldlets/room.txt", "!rooms/room!\n")

      assert {:error, output} = command(["remove", "rooms"])
      assert output =~ "would be lost"
      assert File.exists?(directory)

      assert {:ok, _} = command(["remove", "rooms", "-f"])
      refute File.exists?(directory)
    end

    test "refuses to delete the only copy of a local plugin, unless forced", %{tmp_dir: dir} do
      directory = plugin(dir, "mine")

      assert {:error, output} = command(["remove", "mine"])
      assert output =~ "local plugin"
      assert File.exists?(directory)

      assert {:ok, _} = command(["remove", "mine", "--force"])
      refute File.exists?(directory)
    end

    test "never leaves the plugins directory", %{tmp_dir: dir} do
      kept = write(dir, "worldlets/room.txt", "!game/room!\n")

      assert {:error, output} = command(["remove", "../worldlets", "-f"])
      assert output =~ "not a plugin key"
      assert File.exists?(kept)

      assert {:error, _} = command(["remove", "..", "-f"])
      assert File.exists?(kept)
    end

    test "says when there's no such plugin" do
      assert {:error, output} = command(["remove", "absent"])
      assert output =~ "no plugin called absent"
    end
  end

  describe "plugin eject" do
    setup %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")
      write(dir, "plugins/rooms/worldlets/sub/more.txt", "!rooms/more!\n")
      write(dir, "plugins/rooms/docs/README.md", "# Rooms\n")
      write(dir, "plugins/rooms/scenarios/fixtures/extra.txt", "!rooms/extra!\n")

      write(dir, "plugins/rooms/scenarios/play.txt", """
      apply extra.txt
      apply somewhere/else.txt
      """)

      :ok
    end

    test "puts each part where the game keeps such things", %{tmp_dir: dir} do
      assert {:ok, output} = command(["eject", "rooms"])
      assert output =~ "now part of the game"

      refute File.exists?(Plugin.path("rooms"))
      assert Lock.read() == {:ok, %{}}

      assert File.exists?(Path.join(dir, "worldlets/rooms/room.txt"))
      assert File.exists?(Path.join(dir, "worldlets/rooms/sub/more.txt"))
      assert File.exists?(Path.join(dir, "scenarios/rooms/play.txt"))
      assert File.exists?(Path.join(dir, "scenarios/fixtures/rooms/extra.txt"))
      assert File.exists?(Path.join(dir, "docs/plugins/rooms/README.md"))
    end

    test "the world is the same afterwards, and every worldlet still parses" do
      assert {:ok, _} = command(["eject", "rooms"])

      assert {:ok, %{diagnostics: []}} = Check.run(:all)
      assert {:ok, _, _, []} = World.apply(:all)

      assert Record.get_entity("rooms/room")
      assert Record.get_entity("rooms/more")
      refute Record.get_entity("rooms/extra")
    end

    test "scenarios keep finding their fixtures", %{tmp_dir: dir} do
      assert {:ok, _} = command(["eject", "rooms"])

      text = File.read!(Path.join(dir, "scenarios/rooms/play.txt"))

      assert text =~ "apply rooms/extra.txt"
      assert text =~ "apply somewhere/else.txt"
    end

    test "works on a modified plugin: that's what it's for", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/worldlets/room.txt", "!rooms/room!\ntitle = \"Mine\"\n")

      assert {:ok, _} = command(["eject", "rooms"])
      assert File.read!(Path.join(dir, "worldlets/rooms/room.txt")) =~ "Mine"
    end

    test "refuses when another plugin depends on it", %{tmp_dir: dir} do
      plugin(dir, "exits", depends: ~s({"rooms": "*"}))

      assert {:error, output} = command(["eject", "rooms"])
      assert output =~ "exits depend on it"
      assert File.exists?(Plugin.path("rooms"))
    end

    test "moves nothing if a destination is taken", %{tmp_dir: dir} do
      write(dir, "worldlets/rooms/mine.txt", "!game/mine!\n")

      assert {:error, output} = command(["eject", "rooms"])
      assert output =~ "already exists"

      assert File.exists?(Path.join(Plugin.path("rooms"), "worldlets/room.txt"))
      assert File.exists?(Path.join(Plugin.path("rooms"), "scenarios/fixtures/extra.txt"))
      assert {:ok, %{"rooms" => _}} = Lock.read()
    end
  end

  describe "a command given as one line, as a release does" do
    test "is split into words", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      lock("rooms")

      assert {:ok, output} = command("verify rooms")
      assert output =~ "rooms: as installed"
    end

    test "says so when a quote isn't closed" do
      assert {:error, output} = command("verify 'rooms")
      assert output =~ "quote"
    end

    test "survives a Windows path", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      write(dir, "plugins/rooms/docs/README.md", "# Rooms
")
      output = dir |> Path.join("dist") |> String.replace("/", "\\")

      assert {:ok, _} = command("package rooms --no-scenarios --output #{output}")
      assert File.exists?(Path.join(dir, "dist/rooms-1.0.0.tar.gz"))
    end
  end

  describe "an unknown command" do
    test "shows the usage" do
      assert {:error, output} = command(["dance"])
      assert output =~ "Usage: plugin"

      assert {:error, output} = command(["list", "--wrong"])
      assert output =~ "Usage: plugin"
    end
  end
end
