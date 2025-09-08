defmodule Pythelix.Ports.ClusterCtl do
  @moduledoc """
  Cluster/Node abstraction.
  """

  @doc """
  Ensure the node is currently started.
  """
  @callback ensure_node_started(id :: String.t()) :: :ok

  @doc """
  Start the node cluster with libcluster.
  """
  @callback start_cluster() :: {:ok, pid()} | {:error, term()}

  @doc """
  Wait until the global process is available.
  """
  @callback wait_for_global(module(), integer(), integer()) :: pid() | nil
end
