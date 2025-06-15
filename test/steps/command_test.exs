defmodule Pythelix.Features.CommandTest do
  use Cabbage.Feature, async: false, file: "command.feature"
  use Pythelix.DataCase, async: false

  alias Test.Pythelix.Step

  @moduletag :integration

  setup _context do
    %{clients: %{}}
  end

  defgiven ~r/^I apply the "(?<file>.*?)" worldlet$/, %{file: file}, context do
    Step.apply_worldlet(context, file)
  end

  defgiven ~r/^client (?<id>\d+) connects$/, %{id: id}, context do
    Step.connect_client(context, id)
  end

  defwhen ~r/^client (?<id>\d+) sends "(?<text>.*?)"$/, %{id: id, text: text}, context do
    Step.client_send(context, id, text)
  end

  defthen ~r/^client (?<id>\d+) should receive "(?<text>.*?)"$/, %{id: id, text: text}, context do
    assert Step.client_should_receive(context, id, text)
  end
end
