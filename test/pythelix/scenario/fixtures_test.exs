defmodule Pythelix.Scenario.FixturesTest do
  @moduledoc """
  A scenario often needs something in the world before it can play: an object
  on the ground, an NPC with three hit points rather than ten. Those are
  entities, so they are described in a worldlet — but one that must not reach
  the real game, and must not be mistaken for a transcript.

  The convention is a `fixtures` directory under `scenarios`, applied by the
  scenario that needs it.
  """

  use Pythelix.DataCase, async: false

  alias Pythelix.Scenario
  alias Pythelix.Scenario.Runner

  @moduletag :tmp_dir

  setup do
    {:ok, _path, _number, _notices} = Pythelix.World.apply(Path.expand("worldlets"))

    :ok
  end

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)

    path
  end

  defp play(text) do
    {:ok, scenario} = Scenario.parse(text)

    Runner.run(scenario)
  end

  test "a fixture puts an object in the world for a scenario to find", %{tmp_dir: dir} do
    fixture =
      write(dir, "fixtures/apples.txt", """
      # Objects this scenario needs in place.

      !test/apple!
      parent = "generic/object"
      singular = "a red apple"
      plural = "red apples"
      location = "room/bakery"
      """)

    assert {:ok, _} =
             play("""
             apply #{fixture}

             given Alice in !room/bakery!

             Alice> look
             Alice sees "a red apple"
             """)
  end

  test "two variants of the same thing are two fixtures", %{tmp_dir: dir} do
    # This is the point of naming them: `!test/weak_goblin!` says what it is
    # for, where `hp = 3` set from inside a transcript would not.
    fixture =
      write(dir, "fixtures/goblins.txt", """
      !test/weak_goblin!
      parent = "generic/object"
      singular = "a wounded goblin"
      hp = 3
      location = "room/bakery"

      !test/tough_goblin!
      parent = "generic/object"
      singular = "a snarling goblin"
      hp = 10
      location = "room/bakery"
      """)

    assert {:ok, _} =
             play("""
             apply #{fixture}

             given Alice in !room/bakery!

             Alice> look
             Alice sees "a wounded goblin"
             Alice sees "a snarling goblin"
             """)

    assert Pythelix.Record.get_attribute(Pythelix.Record.get_entity("test/weak_goblin"), "hp") ==
             3

    assert Pythelix.Record.get_attribute(Pythelix.Record.get_entity("test/tough_goblin"), "hp") ==
             10
  end

  test "a fixture that doesn't exist is reported against its line" do
    assert {:failed, [failure]} = play("apply scenarios/fixtures/absent.txt\n")

    assert failure.message =~ "there is no worldlet at"
    assert failure.line == 1
  end
end
