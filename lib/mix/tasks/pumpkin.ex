defmodule Mix.Tasks.Pumpkin do
  use Mix.Task

  @shortdoc "Run all Gherkin features under features/ via Pumpkin"

  def run(_args) do
    Logger.configure(level: :warning)
    :ets.new(:pumpkin_steps, [:named_table, :public, :bag])

    config = [
      database: Path.expand("../pythelix_features.db", __DIR__),
      #database: ":memory:",
      pool_size: 5,
      pool: Ecto.Adapters.SQL.Sandbox
    ]

    # Dynamically reconfigure the Repo
    Application.put_env(:pythelix, Pythelix.Repo, config)
    Application.put_env(:pythelix, :worldlets, false)
    #Application.put_env(:libcluster, :topologies, nil)
    #Application.put_env(:logger, :level, :warning)

    # start your app (so Repo, ETS, etc. are up)
    Mix.Task.run("ecto.create", [])
    Mix.Task.run("ecto.migrate", [])
    {:ok, _} = Application.ensure_all_started(:pythelix)
    Enum.each(Path.wildcard("features/helpers/**/*.ex"), &Code.eval_file/1)
    Enum.each(Path.wildcard("features/steps/**/*.ex"), &Code.eval_file/1)
    #Code.eval_file("features/steps/test.ex")
    Pumpkin.Runner.run()
  end
end
