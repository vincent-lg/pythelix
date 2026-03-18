defmodule Pythelix.Scripting.Namespace.Extended.Client do
  @moduledoc """
  Module containing the eextended methods for the client entity.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Network.Encoding

  defmet msg(script, namespace), [
    {:text, index: 0, keyword: "text", type: :str}
  ] do
    client = Store.get_value(namespace.self)
    client_id = Record.get_attribute(client, "client_id")
    pid = Record.get_attribute(client, "pid")

    # Notify game hub and send message directly to client
    text = Format.String.format(namespace.text)
    Pythelix.Game.Hub.mark_client_with_message(client_id, text, pid)

    {script, :none}
  end

  defmet disconnect(script, namespace), [] do
    client = Store.get_value(namespace.self)
    Pythelix.Network.TCP.Client.disconnect(client)

    {script, :none}
  end

  @doc "Extended property getter for encoding."
  def encoding(_script, self) do
    entity = Store.get_value(self)
    Record.get_attribute(entity, "encoding") || "utf-8"
  end

  @doc "Extended property setter for encoding."
  def encoding(script, self, encoding_ref) do
    entity = Store.get_value(self)
    encoding = Store.get_value(encoding_ref)

    case encoding do
      value when is_binary(value) ->
        if Encoding.supported?(value) do
          id_or_key = Entity.get_id_or_key(entity)
          Record.set_attribute(id_or_key, "encoding", value)

          # Notify the TCP client GenServer about the encoding change
          pid = Record.get_attribute(entity, "pid")
          if is_pid(pid), do: send(pid, {:set_encoding, value})

          {script, encoding_ref}
        else
          supported = Encoding.supported_encodings() |> Enum.join(", ")

          {Script.raise(script, ValueError, "unsupported encoding '#{value}', expected one of: #{supported}"),
           :none}
        end

      _ ->
        {Script.raise(script, TypeError, "encoding must be a string"), :none}
    end
  end

  def owner(_script, self) do
    entity = Store.get_value(self)

    Record.get_attribute(entity, "__owner", :none)
  end

  def owner(script, self, owner) do
    entity = Store.get_value(self)
    owner = Store.get_value(owner)

    case owner do
      :none ->
        Record.set_attribute(entity, "owner", nil)
        {script, :none}

      %Entity{} ->
        Record.set_attribute(Entity.get_id_or_key(entity), "__owner", owner)
        {script, :none}

      _ ->
        {Script.raise(script, TypeError, "owner should be an entity"), :none}
    end
  end
end
