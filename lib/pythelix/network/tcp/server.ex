defmodule Pythelix.Network.TCP.Server do
  use GenServer

  @port 4000

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Return the next incremental client ID.
  """
  def next_client_id do
    GenServer.call(__MODULE__, :next_client_id)
  end

  def init(_) do
    {:ok, socket} =
      :gen_tcp.listen(@port, [:binary, packet: :line, active: true, reuseaddr: true])

    Task.start(fn -> accept_loop(socket) end)
    Logger.info("Starting Telnet server on port #{@port}")
    {:ok, %{socket: socket, next_client_id: 1}}
  end

  def handle_call(:next_client_id, _from, %{next_client_id: id} = state) do
    {:reply, id, %{state | next_client_id: id + 1}}
  end

  defp accept_loop(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(
        Pythelix.Network.TCP.ClientSupervisor,
        {Pythelix.Network.TCP.Client, client_socket}
      )

    :gen_tcp.controlling_process(client_socket, pid)

    accept_loop(socket)
  end
end
