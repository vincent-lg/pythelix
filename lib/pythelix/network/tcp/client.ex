defmodule Pythelix.Network.TCP.Client do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    # :inet.setopts(socket, active: :once)
    {:ok, {socket, nil}, {:continue, :assign_id}}
  end

  def handle_continue(:assign_id, {socket, _}) do
    client_id = Pythelix.Command.Hub.assign_client(self())

    {:noreply, {socket, client_id}}
  end

  def handle_info({:tcp, socket, data}, {socket_state, client_id}) do
    Pythelix.Command.Hub.send_command(client_id, String.trim(data))

    # :inet.setopts(socket, active: :once)
    {:noreply, {socket_state, client_id}}
  end

  def handle_info({:tcp_closed, _socket}, {socket_state, client_id}) do
    IO.puts("Disconnect #{client_id}")
    {:stop, :normal, {socket_state, client_id}}
  end

  def handle_info({:message, message}, {socket, client_id}) do
    :gen_tcp.send(socket, message <> "\n")
    {:noreply, {socket, client_id}}
  end
end
