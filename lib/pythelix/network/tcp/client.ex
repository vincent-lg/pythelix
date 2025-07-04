defmodule Pythelix.Network.TCP.Client do
  use GenServer

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Format

  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, {socket, nil, :queue.new()}, {:continue, :assign_id}}
  end

  def handle_continue(:assign_id, {socket, _, messages}) do
    client_id = Pythelix.Command.Hub.assign_client(self())
    Logger.debug("Connection of #{client_id}")

    {:noreply, {socket, client_id, messages}}
  end

  def handle_info({:tcp, _socket, data}, {socket_state, client_id, messages}) do
    start = System.monotonic_time(:microsecond)
    command = String.trim_trailing(data, "\r\n")
    Pythelix.Command.Hub.send_command(client_id, start, command)

    {:noreply, {socket_state, client_id, messages}}
  end

  def handle_info({:tcp_closed, _socket}, {socket_state, client_id, messages}) do
    Logger.debug("Disconnection of #{client_id}")
    {:stop, :normal, {socket_state, client_id, messages}}
  end

  def handle_info({:message, message}, {socket, client_id, messages}) do
    {:noreply, {socket, client_id, :queue.in(message, messages)}}
  end

  def handle_info({:full, prompt}, {socket, client_id, messages}) do
    text =
      messages
      |> :queue.to_list()
      |> then(fn messages ->
        (prompt && Enum.concat(messages, [prompt])) || messages
      end)
      |> Enum.join("\n")
      |> then(& (!String.ends_with?(&1, "\n") && &1 <> "\n") || &1)
      |> String.replace("\n", "\r\n")

    :gen_tcp.send(socket, text)
    {:noreply, {socket, client_id, :queue.new()}}
  end

  def handle_info(:disconnect, {socket, client_id, messages}) do
    text =
      messages
      |> :queue.to_list()
      |> Enum.join("\n")
      |> then(& (!String.ends_with?(&1, "\n") && &1 <> "\n") || &1)
      |> String.replace("\n", "\r\n")

    Logger.debug("Disconnection of #{client_id}")
    :gen_tcp.send(socket, text)
    :gen_tcp.close(socket)
    {:stop, :normal, {socket, client_id, :queue.new()}}
  end

  def send(%Entity{} = client, message) do
    client_id = Record.get_attribute(client, "client_id")
    pid = Record.get_attribute(client, "pid")
    message = Format.String.format(message)
    GenServer.cast({:global, Pythelix.Command.Hub}, {:message, client_id, message, pid})
  end

  def disconnect(%Entity{} = client) do
    pid = Record.get_attribute(client, "pid")
    Kernel.send(pid, :disconnect)
  end
end
