defmodule Pythelix.PluginTest do
  @moduledoc """
  Plugins are loaded in layers: core, plugins (dependencies first), then the
  game's own worldlets. These tests build small games in a temporary directory.
  """

  use Pythelix.DataCase, async: false

  @moduletag :tmp_dir

  alias Pythelix.{Plugin, Record, World}
  alias Pythelix.Plugin.{Manifest, Requirement}
  alias Pythelix.Scenario
  alias Pythelix.Scenario.Runner
  alias Pythelix.World.{Check, Sources}

  setup %{tmp_dir: dir} do
    previous =
      for key <- [:plugins_path, :worldlets_path], do: {key, Application.get_env(:pythelix, key)}

    Application.put_env(:pythelix, :plugins_path, Path.join(dir, "plugins"))
    Application.put_env(:pythelix, :worldlets_path, Path.join(dir, "worldlets"))

    on_exit(fn ->
      Enum.each(previous, fn {key, value} -> Application.put_env(:pythelix, key, value) end)
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
    version = Keyword.get(opts, :version, "1.0.0")
    depends = Keyword.get(opts, :depends, "{}")
    engine = Keyword.get(opts, :pythelix, ">=0.1")

    write(dir, "plugins/#{key}/plugin.txt", """
    !plugin/#{key}!
    parent = "generic/plugin"
    name = "#{String.capitalize(key)}"
    version = "#{version}"
    pythelix = "#{engine}"
    depends = #{depends}
    """)
  end

  defp attribute(key, name), do: key |> Record.get_entity() |> Record.get_attribute(name)

  defp keys(result) do
    assert {:ok, manifests} = result

    Enum.map(manifests, & &1.key)
  end

  describe "requirements" do
    test "are written the way people write them" do
      assert Requirement.satisfied?("1.2.0", ">=1.0")
      assert Requirement.satisfied?("0.9.0", ">=0.9")
      refute Requirement.satisfied?("0.8.9", ">=0.9")
      assert Requirement.satisfied?("1.5.0", ">=1.0, <2.0")
      refute Requirement.satisfied?("2.0.0", ">=1.0, <2.0")
      assert Requirement.satisfied?("1.5.0", "~>1.2")
      refute Requirement.satisfied?("2.0.0", "~>1.2")
      assert Requirement.satisfied?("1.5.0", "*")
      assert Requirement.satisfied?("1.5.0", "1.5")
      refute Requirement.satisfied?("1.5.1", "1.5")
      assert Requirement.satisfied?("1.5", ">=1.5.0")
    end

    test "no requirement is always met" do
      assert Requirement.satisfied?("1.0.0", nil)
    end

    test "nonsense is refused" do
      refute Requirement.valid?("about one")
      refute Requirement.valid?(">=1.0, nonsense")
      refute Requirement.valid?(3)
      refute Requirement.valid_version?("one")
      refute Requirement.valid_version?(nil)
      assert Requirement.valid_version?("1.2")
      assert Requirement.valid_version?("1.2.0-rc.1")
    end

    test "versions compare as numbers" do
      assert Requirement.compare("1.10.0", "1.9") == :gt
      assert Requirement.compare("1.0", "1.0.0") == :eq
    end
  end

  describe "manifests" do
    test "are read without any world", %{tmp_dir: dir} do
      plugin(dir, "rooms", version: "1.2.0", depends: ~s({"exits": ">=1.0"}))

      assert {:ok, manifest} = Plugin.manifest("rooms")

      assert %Manifest{key: "rooms", name: "Rooms", version: "1.2.0", pythelix: ">=0.1"} =
               manifest

      assert manifest.depends == %{"exits" => ">=1.0"}
    end

    test "must match their directory", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/plugin.txt", """
      !plugin/other!
      parent = "generic/plugin"
      version = "1.0.0"
      """)

      assert {:error, reason} = Plugin.manifest("rooms")
      assert reason =~ "!plugin/rooms!"
    end

    test "must only hold literals", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/plugin.txt", """
      !plugin/rooms!
      parent = "generic/plugin"
      version = compute_version()
      """)

      assert {:error, reason} = Plugin.manifest("rooms")
      assert reason =~ "literal"
      assert reason =~ "compute_version()"
    end

    test "must declare one entity", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/plugin.txt", """
      !plugin/rooms!
      parent = "generic/plugin"
      version = "1.0.0"
      !plugin/more!
      """)

      assert {:error, reason} = Plugin.manifest("rooms")
      assert reason =~ "exactly one entity"
    end

    test "need a version that reads as one", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/plugin.txt", """
      !plugin/rooms!
      parent = "generic/plugin"
      version = "soon"
      """)

      assert {:error, reason} = Plugin.manifest("rooms")
      assert reason =~ "version"
    end

    test "a directory without one is reported", %{tmp_dir: dir} do
      write(dir, "plugins/rooms/worldlets/a.txt", "!test/a!\n")

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "no manifest"
    end

    test "a missing plugin is named" do
      assert {:error, reason} = Plugin.manifest("absent")
      assert reason =~ "absent"
    end
  end

  describe "load order" do
    test "no plugins directory means no plugins" do
      assert Plugin.load_order() == {:ok, []}
    end

    test "is alphabetical among independent plugins", %{tmp_dir: dir} do
      for key <- ["charlie", "alpha", "bravo"], do: plugin(dir, key)

      assert keys(Plugin.load_order()) == ["alpha", "bravo", "charlie"]
    end

    test "puts dependencies first", %{tmp_dir: dir} do
      plugin(dir, "alpha", depends: ~s({"zulu": ">=1.0"}))
      plugin(dir, "bravo")
      plugin(dir, "zulu", depends: ~s({"yankee": "*"}))
      plugin(dir, "yankee")

      assert keys(Plugin.load_order()) == ["bravo", "yankee", "zulu", "alpha"]
    end

    test "reports a missing dependency", %{tmp_dir: dir} do
      plugin(dir, "rooms", depends: ~s({"exits": ">=1.0"}))

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "rooms needs the plugin exits"
    end

    test "reports a version mismatch", %{tmp_dir: dir} do
      plugin(dir, "rooms", depends: ~s({"exits": ">=2.0"}))
      plugin(dir, "exits", version: "1.5.0")

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "needs exits >=2.0"
      assert reason =~ "1.5.0"
    end

    test "reports a cycle", %{tmp_dir: dir} do
      plugin(dir, "one", depends: ~s({"two": "*"}))
      plugin(dir, "two", depends: ~s({"one": "*"}))
      plugin(dir, "three")

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "circle"
      assert reason =~ "one, two"
    end

    test "reports an engine that's too old", %{tmp_dir: dir} do
      plugin(dir, "rooms", pythelix: ">=99.0")

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "needs Pythelix >=99.0"
    end

    test "reports every problem at once", %{tmp_dir: dir} do
      plugin(dir, "one", depends: ~s({"absent": "*"}))
      plugin(dir, "two", pythelix: ">=99.0")

      assert {:error, reason} = Plugin.load_order()
      assert reason =~ "absent"
      assert reason =~ "99.0"
    end

    test "for one plugin, only reads what it depends on", %{tmp_dir: dir} do
      plugin(dir, "rooms", depends: ~s({"exits": "*"}))
      plugin(dir, "exits")
      plugin(dir, "unrelated")
      # A broken plugin elsewhere doesn't get in the way.
      write(dir, "plugins/broken/plugin.txt", "not a manifest")

      assert keys(Plugin.load_order("rooms")) == ["exits", "rooms"]
    end
  end

  describe "layers" do
    test "a game overrides a plugin, which overrides its dependency", %{tmp_dir: dir} do
      plugin(dir, "aaa", depends: ~s({"zzz": "*"}))
      plugin(dir, "zzz")

      write(dir, "plugins/zzz/worldlets/room.txt", """
      !test/room!
      title = "from zzz"
      kept = "from zzz"
      plugin_wins = "from zzz"
      """)

      write(dir, "plugins/aaa/worldlets/room.txt", """
      !test/room!
      plugin_wins = "from aaa"
      game_wins = "from aaa"
      """)

      write(dir, "worldlets/room.txt", """
      !test/room!
      title = "A Muddy Road"
      game_wins = "from the game"
      """)

      assert {:ok, _, _, _} = World.apply(:all)

      assert attribute("test/room", "title") == "A Muddy Road"
      assert attribute("test/room", "kept") == "from zzz"
      assert attribute("test/room", "plugin_wins") == "from aaa"
      assert attribute("test/room", "game_wins") == "from the game"
    end

    test "a game overrides without repeating the parent", %{tmp_dir: dir} do
      plugin(dir, "rooms")

      write(dir, "plugins/rooms/worldlets/room.txt", """
      !rooms/generic!
      inherited = "yes"
      !rooms/road!
      parent = "rooms/generic"
      title = "A Road"
      """)

      write(dir, "worldlets/room.txt", """
      !rooms/road!
      title = "A Muddy Road"
      """)

      assert {:ok, _, _, _} = World.apply(:all)

      assert attribute("rooms/road", "title") == "A Muddy Road"
      assert attribute("rooms/road", "inherited") == "yes"
    end

    test "only a plugin's worldlets and manifest are loaded", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      write(dir, "plugins/rooms/worldlets/a.txt", "!test/a!\n")
      write(dir, "plugins/rooms/worldlets/sub/b.txt", "!test/b!\n")
      write(dir, "plugins/rooms/scenarios/play.txt", "given Alice in !test/a!\n")
      write(dir, "plugins/rooms/scenarios/fixtures/fix.txt", "!test/fixture!\n")
      write(dir, "plugins/rooms/docs/notes.txt", "Just some notes = nothing to read\n")

      assert {:ok, files} = Sources.files({:plugin, "rooms"})

      assert files |> Enum.map(&Path.basename/1) |> Enum.sort() ==
               ["a.txt", "b.txt", "plugin.txt"]

      assert {:ok, ^files} = Sources.files(Path.join(dir, "plugins/rooms"))
    end

    test "a plugin answers from Pythello, and is never saved", %{tmp_dir: dir} do
      plugin(dir, "rooms", version: "1.2.0", depends: ~s({"exits": "*"}))
      plugin(dir, "exits")

      assert {:ok, _, _, _} = World.apply(:all)

      manifest = Record.get_entity("plugin/rooms")

      assert manifest.id == :virtual
      assert attribute("plugin/rooms", "version") == "1.2.0"
      assert attribute("plugin/rooms", "name") == "Rooms"
      assert Record.has_parent?(manifest, "generic/plugin")
      assert {:ok, "1.2.0"} = Pythelix.Scripting.eval("!plugin/rooms!.version")
    end

    test "plugins that can't load stop the apply with an explanation", %{tmp_dir: dir} do
      plugin(dir, "rooms", depends: ~s({"exits": "*"}))

      assert {:error, reason} = World.apply(:all)
      assert reason =~ "rooms needs the plugin exits"
    end

    test "the checker sees the same files", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      write(dir, "plugins/rooms/worldlets/a.txt", "!test/a!\n")
      write(dir, "worldlets/b.txt", "!test/b!\n")

      assert {:ok, result} = Check.run(:all)
      assert result.diagnostics == []

      assert result.files |> Enum.map(&Path.basename/1) |> Enum.sort() ==
               ["a.txt", "b.txt", "plugin.txt"]
    end

    test "the checker reports a plugin's mistake and problems loading", %{tmp_dir: dir} do
      plugin(dir, "rooms")

      write(dir, "plugins/rooms/worldlets/a.txt", """
      !test/a!

      def broken(self):
          if True:
              return 1
      """)

      assert {:ok, %{diagnostics: [_ | _] = diagnostics}} = Check.run(:all)
      assert Enum.any?(diagnostics, &(&1.file =~ "plugins/rooms/worldlets/a.txt"))

      plugin(dir, "more", depends: ~s({"absent": "*"}))

      assert {:ok, %{diagnostics: [problem]}} = Check.run(:all)
      assert problem.message =~ "absent"
    end
  end

  describe "command suppression" do
    setup %{tmp_dir: dir} do
      write(dir, "worldlets/commands.txt", """
      !test/command/emote!
      parent = "generic/command"
      name = "emote"
      aliases = ["em", "pose"]

      def run(character):
          pass_through = 1
      !test/command/wave!
      parent = "generic/command"
      name = "wave"
      """)

      :ok
    end

    defp game_commands, do: attribute("menu/game", "commands")

    test "name = None leaves a command out of the menu, aliases too", %{tmp_dir: dir} do
      write(dir, "worldlets/zz_override.txt", """
      !test/command/emote!
      name = None
      """)

      assert {:ok, _, _, _} = World.apply(:all)

      commands = game_commands()

      assert Map.has_key?(commands, "wave")
      refute Map.has_key?(commands, "emote")
      refute Map.has_key?(commands, "pose")
      refute Map.has_key?(commands, "em")

      # The entity still exists: only what is visible goes away.
      assert Record.get_entity("test/command/emote")
      assert Record.get_location_entity(Record.get_entity("test/command/emote")) == nil
    end

    test "turns off a command that was already in the menu", %{tmp_dir: dir} do
      assert {:ok, _, _, _} = World.apply(:all)
      assert Map.has_key?(game_commands(), "emote")

      write(dir, "worldlets/zz_override.txt", """
      !test/command/emote!
      name = None
      """)

      assert {:ok, _, _, _} = World.apply(:all)

      refute Map.has_key?(game_commands(), "emote")
      refute Map.has_key?(game_commands(), "pose")
    end

    test "can be undone", %{tmp_dir: dir} do
      override =
        write(dir, "worldlets/zz_override.txt", """
        !test/command/emote!
        name = None
        """)

      assert {:ok, _, _, _} = World.apply(:all)
      refute Map.has_key?(game_commands(), "emote")

      File.rm!(override)

      assert {:ok, _, _, _} = World.apply(:all)
      assert Map.has_key?(game_commands(), "emote")
    end

    test "a command inheriting name = None is off too", %{tmp_dir: dir} do
      write(dir, "worldlets/zz_children.txt", """
      !test/command/emote_loud!
      parent = "test/command/emote"
      !test/command/emote!
      name = None
      """)

      assert {:ok, _, _, _} = World.apply(:all)

      refute Map.has_key?(game_commands(), "pose")
    end
  end

  describe "isolation" do
    defp play(text, opts \\ []) do
      {:ok, scenario} = Scenario.parse(text)

      Runner.run(scenario, opts)
    end

    test "a plugin's world leaves out the game and other plugins", %{tmp_dir: dir} do
      plugin(dir, "rooms", depends: ~s({"exits": "*"}))
      plugin(dir, "exits")
      plugin(dir, "unrelated")
      write(dir, "plugins/rooms/worldlets/a.txt", "!rooms/a!\n")
      write(dir, "plugins/exits/worldlets/a.txt", "!exits/a!\n")
      write(dir, "plugins/unrelated/worldlets/a.txt", "!unrelated/a!\n")
      write(dir, "worldlets/a.txt", "!game/a!\n")

      assert {:ok, "plugin rooms", _, _} = World.apply({:plugin, "rooms"})

      assert Record.get_entity("rooms/a")
      assert Record.get_entity("exits/a")
      refute Record.get_entity("unrelated/a")
      refute Record.get_entity("game/a")
    end

    test "the game's overrides don't reach it", %{tmp_dir: dir} do
      plugin(dir, "rooms")

      write(dir, "plugins/rooms/worldlets/a.txt", """
      !rooms/a!
      title = "from the plugin"
      """)

      write(dir, "worldlets/a.txt", """
      !rooms/a!
      title = "from the game"
      """)

      assert {:ok, _, _, _} = World.apply({:plugin, "rooms"})
      assert attribute("rooms/a", "title") == "from the plugin"
    end

    test "a missing plugin is an error" do
      assert {:error, reason} = World.apply({:plugin, "absent"})
      assert reason =~ "absent"
    end

    test "a scenario finds the plugin's own fixtures", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      fixtures = Path.join(dir, "plugins/rooms/scenarios/fixtures")
      write(fixtures, "extra.txt", "!rooms/extra!\n")

      assert {:ok, _, _, _} = World.apply({:plugin, "rooms"})
      assert {:ok, 1} = play("apply extra.txt\n", fixtures: fixtures)
      assert Record.get_entity("rooms/extra")
    end

    test "a scenario without the base plugin explains why it can't log in", %{tmp_dir: dir} do
      plugin(dir, "rooms")
      write(dir, "plugins/rooms/worldlets/a.txt", "!rooms/a!\n")

      assert {:ok, _, _, _} = World.apply({:plugin, "rooms"})

      assert {:failed, [failure]} = play("given Alice in !rooms/a!\n")
      assert failure.message =~ "base plugin"
    end
  end

  describe "the shipped plugins" do
    setup do
      Application.put_env(:pythelix, :plugins_path, Path.expand("plugins"))

      :ok
    end

    test "base and farm load in order, with farm depending on base" do
      assert keys(Plugin.load_order("farm")) == ["base", "farm"]
    end

    test "the base plugin stands on its own" do
      assert {:ok, _, _, _} = World.apply({:plugin, "base"})

      assert Record.get_entity("generic/room")
      assert Record.get_entity("generic/player")
      assert Record.get_entity("command/look")
      refute Record.get_entity("farm/room/road")
    end

    test "they pass the checker" do
      assert {:ok, %{diagnostics: []}} = Check.run({:plugin, "farm"})
    end
  end
end
