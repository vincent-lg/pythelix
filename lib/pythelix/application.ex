defmodule Pythelix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Pythelix.Scripting.Store.init()

    load_password_algorithms()
    |> maybe_start_application()
  end

  def load_password_algorithms() do
    algorithms = Pythelix.Password.Finder.find()
    Application.put_env(:pythelix, :password_algorithms, algorithms)
    names = Enum.map(algorithms, & &1.name())
    number =
      case length(names) do
        0 -> "No"
        1 -> "Only one"
        number -> to_string(number)
      end

    s = (length(names) > 1 && "s") || ""
    f_names = Enum.join(names, ", ")

    if length(names) > 0 do
      Logger.info("#{number} available password algorithm#{s}: #{f_names}")
      :ok
    else
      {:error, "no password algorithm is available"}
    end
  end

  def maybe_start_application({:error, _} = error), do: error
  def maybe_start_application(_) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      %{
        id: :px_cache,
        start: {Cachex, :start_link, [:px_cache, []]}
      },
      %{
        id: :px_diff,
        start: {Cachex, :start_link, [:px_diff, []]}
      },
      %{
        id: :px_tasks,
        start: {Cachex, :start_link, [:px_tasks, []]}
      },
      Pythelix.Repo,
      {Registry, keys: :unique, name: Registry.LongRunning},
      Pythelix.ExecutorSupervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: Pythelix.Network.TCP.ClientSupervisor},
      Pythelix.Network.TCP.Server,
      Pythelix.Command.Hub,
      PythelixWeb.Telemetry,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:pythelix, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:pythelix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pythelix.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pythelix.Finch},
      # Start to serve requests, typically the last entry
      PythelixWeb.Endpoint
    ]
    |> then(fn children ->
      case topologies do
        nil -> children
        _ -> [{Cluster.Supervisor, [topologies, [name: Pythelix.ClusterSupervisor]]} | children]
      end
    end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pythelix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PythelixWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
