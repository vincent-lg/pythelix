defmodule Pythelix.Features.CommandTest do
  use Cabbage.Feature, async: false, file: "command.feature"
  use Pythelix.DataCase, async: false

  @moduletag :integration

  setup _context do
    %{clients: %{}}
  end

  defgiven ~r/^I apply the "(?<file>.*?)" worldlet$/, %{file: file}, context do
    Pythelix.World.apply("test/#{file}")
    {:ok, context}
  end

  defgiven ~r/^client (?<id>\d+) connects$/, %{id: id}, context do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary, packet: :line, active: true])
    clients = Map.put(context.clients, id, socket)
    {:ok, Map.put(context, :clients, clients)}
  end

  defwhen ~r/^client (?<id>\d+) sends "(?<text>.*?)"$/, %{id: id, text: text}, context do
    socket = Map.fetch!(context.clients, id)
    :ok = :gen_tcp.send(socket, "#{text}\r\n")
    {:ok, context}
  end

  defthen ~r/^client (?<id>\d+) should receive "(?<text>.*?)"$/, %{id: id, text: text}, context do
    socket = Map.fetch!(context.clients, id)
    assert recv_until(socket, text, 1000)
  end

  defp recv_until(socket, text, timeout) do
    receive do
      {:tcp, ^socket, received} ->
        (String.trim(received) == text && true) || recv_until(socket, text, timeout)
    after
      timeout ->
        false
    end
  end
end
