defmodule Pythelix.Task.Scenario do
  @moduledoc """
  Play [scenarios](`Pythelix.Scenario`) from the command line and report.

  Each scenario gets a world of its own: the application is started against a
  throwaway database, the scenario applies the worldlets it names, plays, and
  the database is dropped afterwards. A scenario can therefore create, break
  and destroy anything without touching a real game.
  """

  alias Pythelix.Plugin
  alias Pythelix.Scenario
  alias Pythelix.Scenario.{Failure, Runner}

  @doc """
  Start the game alone, so scenarios can be played without disturbing anything.

  No cluster to join, no port to listen on (so a scenario run and a live game
  can coexist), no worldlets until a scenario asks for them, and — this is the
  point — a database of its own in the system temporary directory. A release
  runs `eval` with the real configuration loaded, so without this a scenario
  would play against the real game's data.
  """
  @spec prepare() :: :ok
  def prepare do
    Application.load(:pythelix)

    database = Path.join(System.tmp_dir!(), "pythelix_scenarios.db")
    Enum.each(Path.wildcard(database <> "*"), &File.rm/1)

    Application.put_env(:libcluster, :topologies, nil)
    Application.put_env(:pythelix, :worldlets, false)
    Application.put_env(:pythelix, :telnet_port, nil)
    Application.put_env(:pythelix, :sync_script_execution, true)

    # Time moves only when a scenario says `wait`: ticks and scheduled calls
    # then happen at once, in order, and never on their own between two lines.
    Application.put_env(:pythelix, :clock, Pythelix.Game.Clock.Virtual)

    # Nothing may listen: a release run with PHX_SERVER set would otherwise
    # bind the web port and collide with the game that is already running.
    Application.put_env(
      :pythelix,
      PythelixWeb.Endpoint,
      Keyword.put(Application.get_env(:pythelix, PythelixWeb.Endpoint, []), :server, false)
    )

    Logger.configure(level: :warning)

    repo = Keyword.put(Application.get_env(:pythelix, Pythelix.Repo, []), :database, database)
    Application.put_env(:pythelix, Pythelix.Repo, repo)

    # Migrate before the application starts, on an ordinary pool, the way the
    # `mix test` alias does. Migrating afterwards would fight the migrator the
    # supervision tree already runs, and running DDL through the sandbox pool
    # leaves the schema half-applied.
    {:ok, _, _} = Ecto.Migrator.with_repo(Pythelix.Repo, &Ecto.Migrator.run(&1, :up, all: true))

    # The sandbox pool is how the test suite gives each test its own world.
    # Scenarios want exactly that: one world each, rolled back afterwards.
    Application.put_env(
      :pythelix,
      Pythelix.Repo,
      Keyword.put(repo, :pool, Ecto.Adapters.SQL.Sandbox)
    )

    {:ok, _} = Application.ensure_all_started(:pythelix)
    Ecto.Adapters.SQL.Sandbox.mode(Pythelix.Repo, :manual)

    :ok
  end

  @doc """
  Play a plugin's own scenarios, in a world holding only that plugin and what it
  depends on.

  The game's overrides are allowed to change how a plugin behaves, so playing
  against them would report expected changes as failures. Whether the game still
  behaves as intended with its overrides is for its own scenarios to say.
  """
  @spec run_plugin(binary()) :: :ok | :error
  def run_plugin(key) do
    directory = key |> Plugin.path() |> Path.join("scenarios")

    case files(directory) do
      [] ->
        IO.puts("The plugin #{key} has no scenarios.")

        :ok

      files ->
        world = [source: {:plugin, key}, fixtures: Path.join(directory, "fixtures")]

        files
        |> Enum.map(&play(&1, world))
        |> report()
    end
  end

  @doc """
  Play every scenario under `path` (a file or a directory).
  """
  @spec run(binary() | nil) :: :ok | :error
  def run(path) when path in ["", nil], do: run(directory())

  def run(path) do
    case files(path) do
      [] ->
        IO.puts("No scenario found at #{inspect(path)}.")

        :error

      files ->
        files
        |> Enum.map(&play/1)
        |> report()
    end
  end

  @doc """
  Play the scenarios and stop the VM with a status saying whether they passed.
  """
  @spec main(binary() | [binary()]) :: no_return()
  def main(args) when is_list(args), do: args |> List.first() |> main()

  def main(path) do
    prepare()

    case run(path) do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
  end

  defp files(path) do
    path = Pythelix.Paths.resolve(path)

    cond do
      not File.exists?(path) -> []
      File.dir?(path) -> path |> glob("**/*.txt") |> Enum.reject(&fixture?/1)
      true -> [path]
    end
  end

  # A `fixtures` directory holds worldlets, not scenarios: the entities a
  # scenario needs in place before it can play. They can't live in `worldlets/`
  # — everything there is applied to the real game — and they aren't
  # transcripts, so they are not played. A scenario reaches them with
  # `apply scenarios/fixtures/<name>.txt`.
  defp fixture?(file) do
    file
    |> Path.split()
    |> Enum.any?(&(&1 == "fixtures"))
  end

  defp directory do
    Application.get_env(:pythelix, :scenarios_path, Path.join(File.cwd!(), "scenarios"))
  end

  defp play(file, world \\ []) do
    name = Path.relative_to_cwd(file)
    source = Keyword.get(world, :source, :all)
    runner_opts = Keyword.take(world, [:fixtures])

    case Scenario.parse_file(file) do
      {:error, errors} ->
        IO.puts("\n#{name}")
        Enum.each(errors, &IO.puts("  line #{&1.line}: #{&1.message}\n      #{&1.source}"))

        {:error, name}

      {:ok, scenario} ->
        Enum.each(scenario.notices, &IO.puts("  note  #{&1}"))

        in_clean_world(source, fn ->
          case Runner.run(scenario, runner_opts) do
            {:ok, steps} ->
              IO.puts("  ok    #{name} (#{steps} steps)")

              {:ok, name}

            {:failed, failures} ->
              IO.puts("  FAIL  #{name}")
              Enum.each(failures, &IO.puts(Failure.format(&1)))

              {:error, name}
          end
        end)
    end
  end

  # A world of its own for each scenario: a fresh database transaction that is
  # rolled back afterwards, an empty cache, and the source's worldlets applied.
  # One scenario can therefore never leave anything behind that another depends
  # on — or trips over.
  defp in_clean_world(source, fun) do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Pythelix.Repo, shared: true)

    try do
      Pythelix.Record.Cache.clear()
      Pythelix.Scripting.Store.init()

      case Pythelix.World.apply(source) do
        {:error, reason} ->
          IO.puts("  FAIL  could not apply the worldlets:\n#{reason}")

          {:error, "worldlets"}

        _applied ->
          fun.()
      end
    after
      Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
    end
  end

  defp report(results) do
    {passed, failed} = Enum.split_with(results, &match?({:ok, _}, &1))

    case failed do
      [] ->
        IO.puts("\n#{count(length(passed), "scenario")} passed.")

        :ok

      failed ->
        IO.puts("\n#{length(passed)} passed, #{length(failed)} failed.")

        :error
    end
  end

  # Windows gives us backslashes, and `Path.wildcard/1` treats a backslash as an
  # escape character, so a real directory silently matches nothing. Normalise
  # before globbing (see `Pythelix.Paths`).
  defp glob(directory, pattern) do
    Path.wildcard("#{Pythelix.Paths.normalize(directory)}/#{pattern}")
  end

  defp count(1, singular), do: "1 #{singular}"
  defp count(number, singular), do: "#{number} #{singular}s"
end
