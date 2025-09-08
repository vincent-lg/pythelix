defmodule Test.Pythelix.Adapters.ClusterCtl do
  @behaviour Pythelix.Ports.ClusterCtl

  @doc """
  Ensure the node is currently started.
  """
  @impl true
  @spec ensure_node_started(id :: String.t()) :: :ok
  def ensure_node_started(_id), do: :ok

  @doc """
  Start the node cluster with libcluster.
  """
  @impl true
  @spec start_cluster() :: {:ok, pid()} | {:error, term()}
  def start_cluster(), do: {:ok, self()}

  @doc """
  Wait until the global process is available.
  """
  @impl true
  @spec wait_for_global(module(), integer(), integer()) :: pid() | nil
  def wait_for_global(_mod, _timeout \\ 1000, _interval \\ 100) do
    Process.whereis(Pythelix.Game.Hub)
  end
end
