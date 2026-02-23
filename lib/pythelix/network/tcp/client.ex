defmodule Pythelix.Network.TCP.Client do
  use GenServer, restart: :temporary

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Format
  alias Pythelix.Game.Hub
  alias Pythelix.Game.Modes.Handler, as: ModeHandler

  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, {socket, nil, []}, {:continue, :assign_id}}
  end

  def handle_continue(:assign_id, {socket, _, messages}) do
    client_id = assign_client_id()
    Logger.debug("Connection of #{client_id}")

    # Initialize client entity in the new system
    Hub.run({__MODULE__, :initialize_client, [client_id, self()]})

    {:noreply, {socket, client_id, messages}}
  end

  def handle_info({:tcp, _socket, data}, {socket_state, client_id, messages}) do
    start_time = System.monotonic_time(:microsecond)
    input = String.trim_trailing(data, "\r\n")

    # Send input processing to the new game hub
    Hub.run({__MODULE__, :process_input, [client_id, input, start_time]})

    {:noreply, {socket_state, client_id, messages}}
  end

  def handle_info({:tcp_closed, _socket}, {socket_state, client_id, messages}) do
    Logger.debug("Disconnection of #{client_id}")
    Hub.run({__MODULE__, :disconnect_client, [client_id]})
    {:stop, :normal, {socket_state, client_id, messages}}
  end

  def handle_info({:message, message}, {socket, client_id, messages}) do
    {:noreply, {socket, client_id, [message | messages]}}
  end

  def handle_info({:full, prompt}, {socket, client_id, messages}) do
    text =
      messages
      |> Enum.reverse()
      |> then(fn messages ->
        (prompt && Enum.concat(messages, [prompt])) || messages
      end)
      |> Enum.join("\n")
      |> then(& (!String.ends_with?(&1, "\n") && &1 <> "\n") || &1)
      |> String.replace("\n", "\r\n")

    :gen_tcp.send(socket, text)
    {:noreply, {socket, client_id, []}}
  end

  def handle_cast(:disconnect, {socket, client_id, messages}) do
    text =
      messages
      |> Enum.reverse()
      |> Enum.join("\n")
      |> then(& (!String.ends_with?(&1, "\n") && &1 <> "\n") || &1)
      |> String.replace("\n", "\r\n")

    :gen_tcp.send(socket, text)
    :gen_tcp.shutdown(socket, :write)
    {:noreply, {socket, client_id, []}}
  end

  def send(%Entity{} = client, message) do
    client_id = Record.get_attribute(client, "client_id")
    pid = Record.get_attribute(client, "pid")
    message = Format.String.format(message)
    Pythelix.Game.Hub.mark_client_with_message(client_id, message, pid)
  end

  def disconnect(%Entity{} = client) do
    pid = Record.get_attribute(client, "pid")
    GenServer.cast(pid, :disconnect)
  end

  @doc """
  Generate a unique client ID.
  """
  def assign_client_id do
    System.unique_integer([:positive])
  end

  @doc """
  Initialize client entity (called by the game hub).
  """
  def initialize_client(client_id, pid) do
    parent = Record.get_entity("generic/client")
    key = "client/#{client_id}"

    {:ok, _} = Record.create_entity(virtual: true, key: key, parent: parent)

    Record.set_attribute(key, "client_id", client_id)
    Record.set_attribute(key, "pid", pid)

    {:ok, controls} = Pythelix.Scripting.eval("Controls()")
    Record.set_attribute(key, "controls", controls)

    # Connect the client to the default menu (MOTD) like the old menu connector did
    default_menu_key = Application.get_env(:pythelix, :default_menu, "menu/motd")
    case Record.get_entity(default_menu_key) do
      nil -> :ok
      menu ->
        client_entity = Record.get_entity(key)
        Record.change_location(client_entity, menu)

        # Send the menu text as welcome message and prompt (mimicking old behavior)
        #menu_text = Record.get_attribute(menu, "text", "")
        #if menu_text != "" do
        #  Kernel.send(pid, {:message, menu_text})

        #  # Get and send the menu prompt to complete the welcome
        #  prompt = try do
        #    Pythelix.Method.call_entity(menu, "get_prompt", [client_entity])
        #  rescue
        #    _exception -> ""
        #  end

        #  Kernel.send(pid, {:full, prompt})
        #end
    end
  end

  @doc """
  Process user input (called by the game hub).
  """
  def process_input(client_id, input, start_time) do
    key = "client/#{client_id}"

    case Record.get_entity(key) do
      nil ->
        # Client not found - this shouldn't happen
        :ok

      client ->
        menu = Record.get_location_entity(client)

        if menu do
          # Use the mode handler which will delegate to menu handler if no game modes
          ModeHandler.handle(menu, client, input, start_time)
        else
          # No menu context - send error message
          pid = Record.get_attribute(client, "pid")
          Kernel.send(pid, {:message, "No active menu context."})
        end
    end
  end

  @doc """
  Disconnect client (called by the game hub).
  """
  def disconnect_client(client_id) do
    key = "client/#{client_id}"
    Record.delete_entity(key)
  end
end
