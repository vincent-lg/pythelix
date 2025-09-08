defmodule Pythelix.Adapters.ClusterCtl do
  @behaviour Pythelix.Ports.ClusterCtl

  @doc """
  Ensure the node is currently started.
  """
  @impl true
  @spec ensure_node_started(id :: String.t()) :: :ok
  def ensure_node_started(id) do
    unless Node.alive?() do
      Node.start(String.to_atom("#{id}@127.0.0.1"))
      Node.set_cookie(:mycookie)
    end
    :ok
  end

  @doc """
  Start the node cluster with libcluster.
  """
  @impl true
  @spec start_cluster() :: {:ok, pid()} | {:error, term()}
  def start_cluster() do
    topologies = Application.get_env(:libcluster, :topologies)
    Supervisor.start_link(
      [{Cluster.Supervisor, [topologies, [name: __MODULE__.ClusterSupervisor]]}],
      strategy: :one_for_one
    )
  end

  @doc """
  Wait until the global process is available.
  """
  @impl true
  @spec wait_for_global(module(), integer(), integer()) :: pid() | nil
  def wait_for_global(mod, timeout \\ 1000, interval \\ 100) do
    Pythelix.Task.wait_for_global(mod, timeout, interval)
  end
end
