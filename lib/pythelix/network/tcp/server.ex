defmodule Pythelix.Network.TCP.Server do
  use GenServer

  @port 4000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, socket} =
      :gen_tcp.listen(@port, [:binary, packet: :line, active: true, reuseaddr: true])

    Task.start(fn -> accept_loop(socket) end)
    {:ok, socket}
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
