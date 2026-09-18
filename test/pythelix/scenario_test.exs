defmodule Pythelix.ScenarioTest do
  use ExUnit.Case, async: true

  alias Pythelix.Scenario
  alias Pythelix.Scenario.Step

  defp parse(text) do
    {:ok, scenario} = Scenario.parse(text)

    scenario.steps
  end

  defp kinds(text), do: parse(text) |> Enum.map(& &1.kind)

  describe "the five constructs" do
    test "apply names a path" do
      assert [%Step{kind: :apply, text: "worldlets/farm"}] = parse("apply worldlets/farm\n")
    end

    test "given names a player and a room" do
      assert [%Step{kind: :given, actor: "Alice", text: "!farm/room/field!"}] =
               parse("given Alice in !farm/room/field!\n")
    end

    test "connect names a player with no character yet" do
      assert [%Step{kind: :connect, actor: "Alice"}] = parse("connect Alice\n")
    end

    test "given places a thing, with a count" do
      assert [%Step{kind: :place, count: 30, text: "!gold/coin!", target: "!room/bakery!"}] =
               parse("given 30 !gold/coin! in !room/bakery!\n")
    end

    test "the count is optional" do
      assert [%Step{kind: :place, count: nil, text: "!object/sword!"}] =
               parse("given !object/sword! in !room/bakery!\n")
    end

    test "a thing can be given to a player by name" do
      assert [%Step{kind: :place, count: 5, target: "Alice"}] =
               parse("given 5 !gold/coin! in Alice\n")
    end

    test "a player and a thing are told apart by the key" do
      # `given Alice in !room!` is a player; `given !x! in !room!` is a thing.
      assert [%Step{kind: :given, actor: "Alice"}] = parse("given Alice in !room/a!\n")
      assert [%Step{kind: :place}] = parse("given !object/x! in !room/a!\n")
    end

    test "a player types" do
      assert [%Step{kind: :input, actor: "Alice", text: "harvest wheat"}] =
               parse("Alice> harvest wheat\n")
    end

    test "a player sees" do
      assert [%Step{kind: :sees, actor: "Bob", text: "a bundle of wheat"}] =
               parse(~s|Bob sees "a bundle of wheat"\n|)
    end

    test "a player does not see" do
      assert [%Step{kind: :not_sees, actor: "Bob", text: "a bundle"}] =
               parse(~s|Bob does not see "a bundle"\n|)
    end
  end

  describe "reading a transcript" do
    test "comments and blank lines are ignored" do
      assert [] == parse("# just a note\n\n   \n")
    end

    test "steps keep their line numbers" do
      steps =
        parse("""
        # a comment

        given Alice in !room/a!

        Alice> look
        """)

      assert Enum.map(steps, & &1.line) == [3, 5]
    end

    test "an input keeps its spacing and punctuation" do
      assert [%Step{text: ~s|say "hello, there"|}] = parse(~s|Alice> say "hello, there"\n|)
    end

    test "expected text may contain anything but a quote" do
      assert [%Step{text: "Obvious exits: south."}] =
               parse(~s|Alice sees "Obvious exits: south."\n|)
    end

    test "does not see is read before sees" do
      # "does not see" also contains "see"; the negative must win.
      assert [:not_sees] = kinds(~s|Bob does not see "x"\n|)
    end
  end

  describe "lines that are not constructs" do
    test "every bad line is reported, not just the first" do
      assert {:error, errors} = Scenario.parse("wibble\nwobble\n")
      assert length(errors) == 2
    end

    test "a missing pair of quotes is named as such" do
      assert {:error, [error]} = Scenario.parse("Alice sees no quotes\n")

      assert error.message =~ "double quotes"
      assert error.line == 1
    end

    test "an incomplete given is named" do
      assert {:error, [error]} = Scenario.parse("given Alice\n")

      assert error.message =~ "given Alice in !room/somewhere!"
    end

    test "an unknown line lists what was expected" do
      assert {:error, [error]} = Scenario.parse("Alice waves at Bob\n")

      assert error.message =~ "Name>"
      assert error.source == "Alice waves at Bob"
    end
  end

  describe "render/1" do
    test "a step renders back to what the author wrote" do
      for line <- [
            "apply worldlets/farm",
            "given Alice in !room/a!",
            "given !object/sword! in !room/a!",
            "given 30 !gold/coin! in Alice",
            "connect Newcomer",
            "Alice> harvest wheat",
            ~s|Alice sees "some text"|,
            ~s|Alice does not see "some text"|
          ] do
        assert [step] = parse(line <> "\n")
        assert Step.render(step) == line
      end
    end
  end
end
