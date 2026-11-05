defmodule Pythelix.Plugin.InstallerTest do
  @moduledoc """
  The whole way from a registry to `plugins/`, against a real HTTP server on this
  machine serving what the registry's CI would publish.
  """

  use Pythelix.DataCase, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  alias Pythelix.{Plugin, Record, World}
  alias Pythelix.Plugin.{Archive, Lock, Manifest, Package, Registry, Resolver, TreeHash}
  alias Pythelix.Task.Plugin, as: Command

  defmodule Server do
    @moduledoc false
    @behaviour Plug

    import Plug.Conn

    @impl true
    def init(opts), do: opts

    @impl true
    def call(%{request_path: "/redirect/" <> rest} = conn, _opts) do
      conn
      |> put_resp_header("location", "/#{rest}")
      |> send_resp(302, "")
    end

    def call(conn, root: root) do
      path = Path.join(root, String.trim_leading(conn.request_path, "/"))

      case File.read(path) do
        {:ok, body} -> send_resp(conn, 200, body)
        {:error, _} -> send_resp(conn, 404, "not found")
      end
    end
  end

  setup %{tmp_dir: dir} do
    game = Path.join(dir, "game")
    registry = Path.join(dir, "registry")
    File.mkdir_p!(game)
    File.mkdir_p!(registry)

    {:ok, server} =
      Bandit.start_link(
        plug: {Server, root: registry},
        scheme: :http,
        ip: :loopback,
        port: 0,
        startup_log: false
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    base_url = "http://127.0.0.1:#{port}"

    settings = [
      base_path: game,
      plugins_path: Path.join(game, "plugins"),
      worldlets_path: Path.join(game, "worldlets"),
      scenarios_path: Path.join(game, "scenarios"),
      plugin_index_url: "#{base_url}/index.json"
    ]

    previous = for {key, _} <- settings, do: {key, Application.get_env(:pythelix, key)}
    Application.put_all_env(pythelix: settings)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:pythelix, key)
        {key, value} -> Application.put_env(:pythelix, key, value)
      end)
    end)

    {:ok, game: game, registry: registry, base_url: base_url}
  end

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)

    path
  end

  defp source(dir, key, version, opts) do
    directory = Path.join(dir, "sources/#{key}-#{version}/#{key}")

    write(directory, "plugin.txt", """
    !plugin/#{key}!
    parent = "generic/plugin"
    name = "#{String.capitalize(key)}"
    version = "#{version}"
    pythelix = "#{Keyword.get(opts, :pythelix, ">=0.1")}"
    depends = #{Keyword.get(opts, :depends, "{}")}
    description = "The #{key} plugin."
    """)

    write(directory, "worldlets/thing.txt", """
    !#{key}/thing!
    version = "#{version}"
    """)

    write(directory, "docs/README.md", "# #{key}\n")

    directory
  end

  # What the registry's CI does for one version: build, upload, add to the index.
  defp publish(%{registry: registry, base_url: base_url, tmp_dir: dir}, key, version, opts \\ []) do
    directory = source(dir, key, version, opts)
    name = "#{key}-#{version}.tar.gz"
    archive = Path.join(registry, name)

    assert :ok = Archive.build(directory, archive)

    index =
      case File.read(Path.join(registry, "index.json")) do
        {:ok, text} ->
          {:ok, index} = Registry.decode_index(text)
          index

        {:error, :enoent} ->
          %{}
      end

    assert {:ok, index} = Package.add_to_index(index, archive, "#{base_url}/#{name}")
    File.write!(Path.join(registry, "index.json"), Registry.encode_index(index))

    archive
  end

  defp tamper_index(%{registry: registry}, fun) do
    path = Path.join(registry, "index.json")
    {:ok, index} = Registry.decode_index(File.read!(path))
    File.write!(path, Registry.encode_index(fun.(index)))
  end

  defp command(args), do: with_io(fn -> Command.run(args) end)

  defp installed_version(key) do
    {:ok, manifest} = Plugin.manifest(key)

    manifest.version
  end

  defp raw_tar(path, entries) do
    :ok = :erl_tar.create(String.to_charlist(path), entries, [:compressed])

    path
  end

  describe "the resolver" do
    setup do
      version = fn opts -> Map.new(opts, fn {key, value} -> {to_string(key), value} end) end

      index = %{
        "rooms" => %{
          "1.0.0" => version.(depends: %{}),
          "1.2.0" => version.(depends: %{"exits" => ">=1.0"}),
          "9.0.0" => version.(pythelix: ">=99.0")
        },
        "exits" => %{"1.0.0" => %{}, "1.5.0" => %{}, "2.0.0" => %{}},
        "doors" => %{"1.0.0" => version.(depends: %{"exits" => "<1.5"})},
        "cycle_a" => %{"1.0.0" => version.(depends: %{"cycle_b" => "*"})},
        "cycle_b" => %{"1.0.0" => version.(depends: %{"cycle_a" => "*"})}
      }

      {:ok, index: index}
    end

    defp versions({:ok, choices}),
      do: Map.new(choices, fn {key, version, _} -> {key, version} end)

    test "takes the latest version fitting the engine, and follows it", %{index: index} do
      assert versions(Resolver.plan([{"rooms", nil}], index, %{})) ==
               %{"rooms" => "1.2.0", "exits" => "2.0.0"}
    end

    test "respects an explicit version", %{index: index} do
      assert versions(Resolver.plan([{"rooms", "==1.0.0"}], index, %{})) == %{"rooms" => "1.0.0"}
    end

    test "keeps what's installed when it fits", %{index: index} do
      assert versions(Resolver.plan([{"rooms", nil}], index, %{"exits" => "1.2.0"})) ==
               %{"rooms" => "1.2.0"}
    end

    test "refuses what's installed when it doesn't", %{index: index} do
      assert {:error, reason} = Resolver.plan([{"doors", nil}], index, %{"exits" => "1.8.0"})
      assert reason =~ "doors needs exits <1.5"
      assert reason =~ "Try updating exits"
    end

    test "two plugins needing different things settle on what fits both", %{index: index} do
      assert versions(Resolver.plan([{"doors", nil}, {"rooms", nil}], index, %{})) ==
               %{"doors" => "1.0.0", "rooms" => "1.2.0", "exits" => "1.0.0"}
    end

    test "says when nothing fits", %{index: index} do
      assert {:error, reason} = Resolver.plan([{"rooms", "==9.0.0"}], index, %{})
      assert reason =~ "No version of rooms fits"
      assert reason =~ "1.0.0, 1.2.0, 9.0.0"
    end

    test "says when a plugin isn't published", %{index: index} do
      assert {:error, reason} = Resolver.plan([{"absent", nil}], index, %{})
      assert reason =~ "no plugin called absent"
    end

    test "survives a cycle in the registry", %{index: index} do
      assert versions(Resolver.plan([{"cycle_a", nil}], index, %{})) ==
               %{"cycle_a" => "1.0.0", "cycle_b" => "1.0.0"}
    end
  end

  describe "archives" do
    test "hold a plugin's files at the root", %{tmp_dir: dir} do
      directory = source(dir, "rooms", "1.0.0", [])
      archive = Path.join(dir, "out/rooms.tar.gz")
      destination = Path.join(dir, "extracted")

      assert :ok = Archive.build(directory, archive)
      assert :ok = Archive.extract(archive, destination)

      assert TreeHash.compute(destination) == TreeHash.compute(directory)
    end

    test "refuse to be built with other files", %{tmp_dir: dir} do
      directory = source(dir, "rooms", "1.0.0", [])
      write(directory, "run_me.exs", "IO.puts(:oops)")

      assert {:error, reason} = Archive.build(directory, Path.join(dir, "out.tar.gz"))
      assert reason =~ "run_me.exs"
    end

    for {name, entry} <- [
          {"an absolute path", "/etc/evil.txt"},
          {"a parent directory", "../evil.txt"},
          {"a parent directory further in", "worldlets/../../evil.txt"},
          {"a backslash", "..\\evil.txt"},
          {"a drive letter", "C:/evil.txt"},
          {"another extension", "worldlets/evil.ex"},
          {"no extension", "evil"}
        ] do
      test "refuse #{name}", %{tmp_dir: dir} do
        archive = raw_tar(Path.join(dir, "evil.tar.gz"), [{~c"#{unquote(entry)}", "evil"}])
        destination = Path.join(dir, "out/extracted")

        assert {:error, reason} = Archive.extract(archive, destination)
        assert reason =~ "refused"

        # Refused before anything was written.
        refute File.exists?(destination)
        refute File.exists?(Path.join(dir, "out/evil.txt"))
      end
    end

    test "refuse a symbolic link", %{tmp_dir: dir} do
      target = write(dir, "target.txt", "x")
      link = Path.join(dir, "link.txt")

      case File.ln_s(target, link) do
        :ok ->
          archive = Path.join(dir, "link.tar.gz")

          :ok =
            :erl_tar.create(
              String.to_charlist(archive),
              [{~c"link.txt", String.to_charlist(link)}],
              [
                :compressed
              ]
            )

          assert {:error, reason} = Archive.extract(archive, Path.join(dir, "out"))
          assert reason =~ "not a regular file"

        # Windows only lets some users create links.
        {:error, _} ->
          :ok
      end
    end

    test "refuse what isn't an archive", %{tmp_dir: dir} do
      path = write(dir, "fake.tar.gz", "not an archive")

      assert {:error, reason} = Archive.extract(path, Path.join(dir, "out"))
      assert reason =~ "cannot be read"
    end
  end

  describe "plugin install" do
    test "downloads, checks, extracts and locks", context do
      publish(context, "rooms", "1.0.0")

      assert {:ok, output} = command(["install", "rooms"])

      assert output =~ "Installed rooms 1.0.0"
      assert output =~ "bin/apply"

      assert installed_version("rooms") == "1.0.0"
      assert File.exists?(Path.join(Plugin.path("rooms"), "worldlets/thing.txt"))

      assert {:ok, %{"rooms" => entry}} = Lock.read()
      assert entry.version == "1.0.0"
      assert entry.source == "#{context.base_url}/rooms-1.0.0.tar.gz"

      assert entry.archive_hash ==
               TreeHash.sha256(File.read!(Path.join(context.registry, "rooms-1.0.0.tar.gz")))

      assert entry.tree_hash == TreeHash.compute(Plugin.path("rooms")).tree

      # No trace of the work directory.
      assert Enum.map(Plugin.directories(), &Path.basename/1) == ["rooms"]
      assert File.ls!(Plugin.directory()) == ["rooms"]
    end

    test "gives the world the plugin's entities", context do
      publish(context, "rooms", "1.0.0")

      assert {:ok, _} = command(["install", "rooms"])
      assert {:ok, _, _, []} = World.apply(:all)

      thing = Record.get_entity("rooms/thing")
      assert Record.get_attribute(thing, "version") == "1.0.0"
    end

    test "takes the latest version, or the one asked for", context do
      publish(context, "rooms", "1.0.0")
      publish(context, "rooms", "1.10.0")
      publish(context, "rooms", "1.9.0")

      assert {:ok, _} = command(["install", "rooms"])
      assert installed_version("rooms") == "1.10.0"

      assert {:ok, _} = command(["remove", "rooms"])
      assert {:ok, _} = command(["install", "rooms@1.9.0"])
      assert installed_version("rooms") == "1.9.0"
    end

    test "installs dependencies, with what fits", context do
      publish(context, "exits", "1.0.0")
      publish(context, "exits", "2.0.0")
      publish(context, "rooms", "1.0.0", depends: ~s({"exits": "<2.0"}))

      assert {:ok, output} = command(["install", "rooms"])

      assert output =~ "Installed exits 1.0.0"
      assert output =~ "Installed rooms 1.0.0"
      assert {:ok, %{"exits" => _, "rooms" => _}} = Lock.read()
      assert {:ok, [%Manifest{key: "exits"}, %Manifest{key: "rooms"}]} = Plugin.load_order()
    end

    test "follows redirects, as release assets do", context do
      publish(context, "rooms", "1.0.0")

      tamper_index(context, fn index ->
        update_in(index["rooms"]["1.0.0"]["url"], fn url ->
          String.replace(url, "/rooms-", "/redirect/rooms-")
        end)
      end)

      assert {:ok, _} = command(["install", "rooms"])
    end

    test "refuses an archive whose hash isn't the published one", context do
      publish(context, "rooms", "1.0.0")

      tamper_index(context, fn index ->
        put_in(index["rooms"]["1.0.0"]["sha256"], String.duplicate("0", 64))
      end)

      assert {:error, output} = command(["install", "rooms"])

      assert output =~ "isn't the one the registry describes"
      refute File.exists?(Plugin.path("rooms"))
      assert Lock.read() == {:ok, %{}}
    end

    test "refuses an archive with an unsafe path, leaving nothing behind", context do
      publish(context, "rooms", "1.0.0")
      archive = Path.join(context.registry, "rooms-1.0.0.tar.gz")
      File.rm!(archive)
      raw_tar(archive, [{~c"../../evil.txt", "evil"}])
      hash = TreeHash.sha256(File.read!(archive))

      tamper_index(context, fn index -> put_in(index["rooms"]["1.0.0"]["sha256"], hash) end)

      assert {:error, output} = command(["install", "rooms"])

      assert output =~ "refused"
      refute File.exists?(Path.join(context.game, "evil.txt"))
      assert File.ls!(Plugin.directory()) == []
    end

    test "refuses an archive claiming to be another version", context do
      publish(context, "rooms", "1.0.0")

      tamper_index(context, fn index ->
        put_in(index, ["rooms", "2.0.0"], index["rooms"]["1.0.0"])
      end)

      assert {:error, output} = command(["install", "rooms"])
      assert output =~ "says it holds version 1.0.0"
      refute File.exists?(Plugin.path("rooms"))
    end

    test "a failing dependency leaves everything as it was", context do
      publish(context, "exits", "1.0.0")
      publish(context, "rooms", "1.0.0", depends: ~s({"exits": "*"}))
      File.rm!(Path.join(context.registry, "rooms-1.0.0.tar.gz"))

      assert {:error, output} = command(["install", "rooms"])

      assert output =~ "404"
      assert File.ls!(Plugin.directory()) == []
      assert Lock.read() == {:ok, %{}}
    end

    test "refuses something already installed", context do
      publish(context, "rooms", "1.0.0")

      assert {:ok, _} = command(["install", "rooms"])
      assert {:error, output} = command(["install", "rooms"])
      assert output =~ "already installed"
    end

    test "won't replace a local plugin, unless forced", context do
      publish(context, "rooms", "1.0.0")
      mine = write(Plugin.path("rooms"), "plugin.txt", "!plugin/rooms!\n")

      assert {:error, output} = command(["install", "rooms"])
      assert output =~ "local plugin"
      assert File.read!(mine) == "!plugin/rooms!\n"

      assert {:ok, _} = command(["install", "rooms", "-f"])
      assert installed_version("rooms") == "1.0.0"
      assert {:ok, %{"rooms" => _}} = Lock.read()
    end

    test "says when a plugin isn't published", context do
      publish(context, "rooms", "1.0.0")

      assert {:error, output} = command(["install", "absent"])
      assert output =~ "no plugin called absent"
    end

    test "says when the registry can't be reached" do
      Application.put_env(:pythelix, :plugin_index_url, "http://127.0.0.1:1/index.json")

      assert {:error, output} = command(["install", "rooms"])
      assert output =~ "Cannot reach"
    end

    test "refuses a key wandering out of the plugins directory", context do
      publish(context, "rooms", "1.0.0")

      assert {:error, output} = command(["install", "../rooms"])
      assert output =~ "not a plugin key"
    end
  end

  describe "plugin update" do
    setup context do
      publish(context, "rooms", "1.0.0")
      assert {:ok, _} = command(["install", "rooms"])

      :ok
    end

    test "moves to the latest version, replacing the files", context do
      publish(context, "rooms", "1.1.0")
      stale = Path.join(Plugin.path("rooms"), "worldlets/thing.txt")

      assert {:ok, output} = command(["update", "rooms"])

      assert output =~ "Installed rooms 1.1.0"
      assert installed_version("rooms") == "1.1.0"
      assert File.read!(stale) =~ "1.1.0"
      assert {:ok, %{"rooms" => %{version: "1.1.0"}}} = Lock.read()
      assert File.ls!(Plugin.directory()) == ["rooms"]
    end

    test "with no key, updates every locked plugin and leaves local ones", context do
      publish(context, "exits", "1.0.0")
      assert {:ok, _} = command(["install", "exits"])
      publish(context, "rooms", "2.0.0")
      publish(context, "exits", "2.0.0")
      publish(context, "mine", "5.0.0")

      write(Plugin.path("mine"), "plugin.txt", """
      !plugin/mine!
      parent = "generic/plugin"
      version = "1.0.0"
      """)

      assert {:ok, _} = command(["update"])

      assert installed_version("rooms") == "2.0.0"
      assert installed_version("exits") == "2.0.0"
      assert installed_version("mine") == "1.0.0"
    end

    test "says when it's up to date, without touching anything" do
      {:ok, before} = Lock.read()

      assert {:ok, output} = command(["update", "rooms"])

      assert output =~ "already up to date"
      assert Lock.read() == {:ok, before}
    end

    test "refuses a modified plugin, unless forced", context do
      publish(context, "rooms", "1.1.0")
      edited = write(Plugin.path("rooms"), "worldlets/thing.txt", "!rooms/thing!\nmine = 1\n")

      assert {:error, output} = command(["update", "rooms"])

      assert output =~ "would be lost"
      assert output =~ Pythelix.Paths.display("worldlets/thing.txt")
      assert output =~ "docs/plugins.md"
      assert installed_version("rooms") == "1.0.0"
      assert File.read!(edited) =~ "mine"

      assert {:ok, _} = command(["update", "rooms", "-f"])
      assert installed_version("rooms") == "1.1.0"
      refute File.read!(edited) =~ "mine"
    end

    test "game overrides survive it, living elsewhere", context do
      write(context.game, "worldlets/override.txt", """
      !rooms/thing!
      title = "Mine"
      """)

      publish(context, "rooms", "1.1.0")
      assert {:ok, _} = command(["update", "rooms"])
      assert {:ok, _, _, []} = World.apply(:all)

      thing = Record.get_entity("rooms/thing")
      assert Record.get_attribute(thing, "title") == "Mine"
      assert Record.get_attribute(thing, "version") == "1.1.0"
    end

    test "respects what other plugins need", context do
      publish(context, "doors", "1.0.0", depends: ~s({"rooms": "<2.0"}))
      assert {:ok, _} = command(["install", "doors"])
      publish(context, "rooms", "1.5.0")
      publish(context, "rooms", "2.0.0")

      assert {:ok, _} = command(["update", "rooms"])

      assert installed_version("rooms") == "1.5.0"
    end

    test "pulls in a new dependency", context do
      publish(context, "exits", "1.0.0")
      publish(context, "rooms", "2.0.0", depends: ~s({"exits": ">=1.0"}))

      assert {:ok, _} = command(["update", "rooms"])

      assert installed_version("exits") == "1.0.0"
      assert installed_version("rooms") == "2.0.0"
    end

    test "says what's wrong with a local plugin", context do
      write(context.game, "plugins/mine/plugin.txt", "!plugin/mine!\n")

      assert {:error, output} = command(["update", "mine"])
      assert output =~ "local plugin"
    end

    test "says when there's no such plugin" do
      assert {:error, output} = command(["update", "absent"])
      assert output =~ "no plugin called"
    end
  end

  describe "plugin list" do
    test "shows what's published and not installed", context do
      publish(context, "rooms", "1.0.0")
      publish(context, "exits", "1.0.0")
      publish(context, "exits", "1.2.0")
      assert {:ok, _} = command(["install", "rooms"])

      assert {:ok, output} = command(["list"])

      assert output =~ "rooms 1.0.0: installed"
      assert output =~ "exits 1.2.0: available - The exits plugin."
      refute output =~ "rooms 1.0.0: available"
    end

    test "still works offline", context do
      write(context.game, "plugins/mine/plugin.txt", """
      !plugin/mine!
      parent = "generic/plugin"
      version = "1.0.0"
      """)

      Application.put_env(:pythelix, :plugin_index_url, "http://127.0.0.1:1/index.json")

      assert {:ok, output} = command(["list"])

      assert output =~ "mine 1.0.0: local"
      assert output =~ "can't be listed"
    end
  end

  describe "plugin package" do
    defp local_plugin(game, key, version \\ "1.0.0") do
      write(game, "plugins/#{key}/plugin.txt", """
      !plugin/#{key}!
      parent = "generic/plugin"
      version = "#{version}"
      """)

      write(game, "plugins/#{key}/worldlets/thing.txt", "!#{key}/thing!\n")
      write(game, "plugins/#{key}/docs/README.md", "# #{key}\n")

      Plugin.path(key)
    end

    defp package(args), do: command(["package" | args] ++ ["--no-scenarios"])

    test "builds an archive and gives its hash", %{game: game} do
      local_plugin(game, "rooms")

      assert {:ok, output} = package(["rooms"])

      archive = Path.join(game, "rooms-1.0.0.tar.gz")
      assert File.exists?(archive)
      assert output =~ "sha256: #{TreeHash.sha256(File.read!(archive))}"
    end

    test "writes where it's told", %{game: game, tmp_dir: dir} do
      local_plugin(game, "rooms")

      assert {:ok, _} = package(["rooms", "--output", Path.join(dir, "dist")])
      assert File.exists?(Path.join(dir, "dist/rooms-1.0.0.tar.gz"))
    end

    test "refuses files that aren't allowed", %{game: game} do
      directory = local_plugin(game, "rooms")
      write(directory, "lib/evil.ex", "defmodule Evil, do: nil")

      assert {:error, output} = package(["rooms"])
      assert output =~ "lib/evil.ex"
      refute File.exists?(Path.join(game, "rooms-1.0.0.tar.gz"))
    end

    test "needs a README", %{game: game} do
      directory = local_plugin(game, "rooms")
      File.rm!(Path.join(directory, "docs/README.md"))

      assert {:error, output} = package(["rooms"])
      assert output =~ "docs/README.md"
    end

    test "refuses worldlets that don't parse", %{game: game} do
      directory = local_plugin(game, "rooms")

      write(directory, "worldlets/thing.txt", """
      !rooms/thing!

      def broken(self):
          if True:
              return 1
      """)

      assert {:error, output} = package(["rooms"])
      assert output =~ "endif"
    end

    test "needs its dependencies to be there", %{game: game} do
      directory = local_plugin(game, "rooms")

      write(directory, "plugin.txt", """
      !plugin/rooms!
      parent = "generic/plugin"
      version = "1.0.0"
      depends = {"exits": "*"}
      """)

      assert {:error, output} = package(["rooms"])
      assert output =~ "rooms needs the plugin exits"
    end

    test "says when there's no such plugin" do
      assert {:error, output} = package(["absent"])
      assert output =~ "no plugin called"
    end

    test "against an index, a new version has to be greater", %{game: game, tmp_dir: dir} do
      directory = local_plugin(game, "rooms", "1.2.0")
      dist = Path.join(dir, "dist")
      index = Path.join(dir, "index.json")

      assert {:ok, _} = package(["rooms", "--output", dist, "--index", index])
      archive = Path.join(dist, "rooms-1.2.0.tar.gz")
      assert {:ok, _} = command(["index", index, archive, "https://example.com/rooms.tar.gz"])

      local_plugin(game, "rooms", "1.1.0")
      assert {:error, output} = package(["rooms", "--output", dist, "--index", index])
      assert output =~ "should be greater than the last version, 1.2.0"

      local_plugin(game, "rooms", "1.3.0")
      assert {:ok, _} = package(["rooms", "--output", dist, "--index", index])
      assert File.exists?(Path.join(dist, "rooms-1.3.0.tar.gz"))

      assert directory == Plugin.path("rooms")
    end

    test "against an index, a published version is skipped or must not change", %{
      game: game,
      tmp_dir: dir
    } do
      directory = local_plugin(game, "rooms")
      dist = Path.join(dir, "dist")
      index = Path.join(dir, "index.json")

      assert {:ok, _} = package(["rooms", "--output", dist, "--index", index])
      archive = Path.join(dist, "rooms-1.0.0.tar.gz")
      assert {:ok, _} = command(["index", index, archive, "https://example.com/rooms.tar.gz"])
      File.rm!(archive)

      assert {:ok, output} = package(["rooms", "--output", dist, "--index", index])
      assert output =~ "already published"
      refute File.exists?(archive)

      write(directory, "worldlets/thing.txt", "!rooms/thing!\nchanged = 1\n")

      assert {:error, output} = package(["rooms", "--output", dist, "--index", index])
      assert output =~ "already published, and has changed"
    end

    test "what it builds can be installed", context do
      local_plugin(context.game, "built")

      dist = context.registry
      index = Path.join(context.registry, "index.json")
      url = "#{context.base_url}/built-1.0.0.tar.gz"

      assert {:ok, _} = package(["built", "--output", dist])
      assert {:ok, _} = command(["index", index, Path.join(dist, "built-1.0.0.tar.gz"), url])

      assert {:ok, _} = command(["remove", "built", "-f"])
      assert {:ok, output} = command(["install", "built"])

      assert output =~ "Installed built 1.0.0"
      assert {:ok, %{"built" => _}} = Lock.read()
    end
  end

  describe "the index" do
    test "reads back what it wrote, sorted" do
      index = %{
        "zulu" => %{"1.0.0" => %{"url" => "z"}},
        "alpha" => %{"2.0.0" => %{}, "1.0.0" => %{}}
      }

      text = Registry.encode_index(index)

      assert Registry.decode_index(text) == {:ok, index}
      assert :binary.match(text, "alpha") < :binary.match(text, "zulu")
    end

    test "something else is said not to be one" do
      assert {:error, _} = Registry.decode_index("{}")
      assert {:error, _} = Registry.decode_index("nope")
    end
  end
end
