defmodule Pythelix.MixProject do
  use Mix.Project

  def project do
    [
      app: :pythelix,
      version: "0.5.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        pythelix: [
          steps: [:assemble, &copy_extra_files/1]
        ]
      ],
      compilers: Mix.compilers() ++ [:pythello],
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Pythelix.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        pumpkin: :test,
      ]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:codepagex, "~> 0.1.9"},
      {:nimble_parsec, "~> 1.4"},
      {:unicode_set, "~> 1.5.0"},
      {:libcluster, "~> 3.5"},
      {:cachex, "~> 4.0"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:gherkin, "~> 2.0"}
    ]
    |> then(fn deps ->
      impl = (match?({:win32, _}, :os.type) && "windows") || "linux"
      file = "deps_#{impl}.ex"

      if File.exists?(file) do
        {additions, _} = Code.eval_file(file)

        Enum.concat(additions, deps)
      else
        Mix.raise("Unknown HASH_BACKEND=#{impl} or missing deps file.")
      end
    end)
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind pythelix", "esbuild pythelix"],
      "assets.deploy": [
        "tailwind pythelix --minify",
        "esbuild pythelix --minify",
        "phx.digest"
      ]
    ]
  end

  defp copy_extra_files(release) do
    File.cp_r!("docs", Path.join(release.path, "docs"))
    File.cp_r!("worldlets", Path.join(release.path, "worldlets"))

    release
  end
end
