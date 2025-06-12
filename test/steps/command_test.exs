defmodule Pythelix.Features.CommandTest do
  use Cabbage.Feature, async: false, file: "command.feature"

  @moduletag :integration

  setup context do
    Pythelix.Record.Cache.clear()
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Pythelix.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    %{clients: %{}}
  end

  defgiven ~r/^I apply the "(?<file>.*?)" worldlet$/, %{file: file}, context do
    IO.puts("Applying worldlet #{file}")
    Pythelix.World.apply("test/#{file}")
    {:ok, context}
  end

  defgiven ~r/^client (?<id>\d+) connects$/, %{id: id}, context do
    IO.puts("client #{id} connects")
    {:ok, socket} = :gen_tcp.connect('localhost', 4000, [:binary, packet: :line, active: false])
    clients = Map.put(context.clients, id, socket)
    {:ok, Map.put(context, :clients, clients)}
  end

  defwhen ~r/^client (?<id>\d+) sends "(?<text>.*?)"$/, %{id: id, text: text}, context do
    IO.puts("Client #{id} sends #{text}")
    socket = Map.fetch!(context.clients, id)
    :ok = :gen_tcp.send(socket, "#{text}\r\n")
    {:ok, context}
  end

  defthen ~r/^client (?<id>\d+) should receive "(?<text>.*?)"$/, %{id: id, text: text}, context do
    IO.puts("client #{id} should receive #{text}")
    socket = Map.fetch!(context.clients, id)
    {:ok, reply} = :gen_tcp.recv(socket, 0, 1000)
    IO.inspect(reply)
    assert 1
  end
end
