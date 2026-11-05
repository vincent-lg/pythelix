defmodule Pythelix.Menu.BrokenMenuTest do
  @moduledoc """
  A menu being written is, more often than not, a menu that doesn't work yet.
  When its `get_text` raises, the builder needs two things: the Pythello
  traceback in the log, and a sign in the client that the menu is broken.
  """

  use Pythelix.DataCase, async: false

  import ExUnit.CaptureLog

  alias Pythelix.Scenario
  alias Pythelix.Scenario.Runner

  @moduletag :tmp_dir

  setup do
    {:ok, _path, _number, _notices} = Pythelix.World.apply(:all)

    :ok
  end

  defp play(text) do
    {:ok, scenario} = Scenario.parse(text)

    Runner.run(scenario)
  end

  test "a menu whose get_text raises says so to the client and logs only the traceback",
       %{tmp_dir: dir} do
    fixture = Path.join(dir, "broken.txt")

    File.write!(fixture, """
    !menu/broken!
    parent = "generic/menu"

    def get_text(client):
        return client.nonexistent_attribute

    !menu/motd!

    def enter(client):
        client.location = !menu/broken!
    """)

    log =
      capture_log(fn ->
        assert {:ok, _} =
                 play("""
                 apply #{fixture}

                 connect Newcomer
                 Newcomer sees "menu could not be displayed"
                 """)
      end)

    assert log =~ "AttributeError"
    assert log =~ "nonexistent_attribute"
    refute log =~ "FunctionClauseError"
  end
end
