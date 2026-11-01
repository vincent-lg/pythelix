defmodule Pythelix.Scenario.RunnerTest do
  @moduledoc """
  Scenarios are played against the real engine, using the shipped worldlets.
  These check that a transcript really does exercise commands, rooms and what
  other players in the room see.
  """

  use Pythelix.DataCase, async: false

  alias Pythelix.Scenario
  alias Pythelix.Scenario.Runner

  setup do
    {:ok, _path, _number, _notices} = Pythelix.World.apply(Path.expand("worldlets"))

    :ok
  end

  defp play(text) do
    {:ok, scenario} = Scenario.parse(text)

    Runner.run(scenario)
  end

  describe "a player in a room" do
    test "sees the room when looking" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!

               Alice> look
               Alice sees "bakery"
               """)
    end

    test "an unknown command is reported to them" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!

               Alice> xyzzy
               Alice sees "Command not found"
               """)
    end
  end

  describe "two players in the same room" do
    test "one sees what the other says" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given Bob in !room/bakery!

               Alice> say hello there
               Alice sees "hello there"
               Bob sees "hello there"
               """)
    end

    test "several expectations can read the same exchange" do
      # Both of these look at what Alice received from one input: reading must
      # not consume.
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!

               Alice> say hello there
               Alice sees "hello"
               Alice sees "there"
               """)
    end
  end

  describe "connect" do
    test "a fresh client meets the login menus, with no character" do
      assert {:ok, _} =
               play("""
               connect Newcomer
               Newcomer sees "Welcome to the Pythelix Engine"
               Newcomer sees "Enter your username"
               """)
    end

    test "the client can walk through the menus" do
      assert {:ok, _} =
               play("""
               connect Newcomer

               Newcomer> nosuchaccount
               Newcomer sees "doesn't exist"

               Newcomer> new
               Newcomer sees "Enter your new username"
               """)
    end
  end

  describe "putting things in the world" do
    test "a stackable becomes one stack of that many" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given 30 !object/gold_coin! in !room/bakery!

               Alice> look
               Alice sees "30 gold coins"
               """)
    end

    test "one of something is the default" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given !object/gold_coin! in !room/bakery!

               Alice> look
               Alice sees "a gold coin"
               """)
    end

    test "a stack answers to its plural name" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given 30 !object/gold_coin! in !room/bakery!

               Alice> get 20 gold coins
               Alice sees "You pick up 20 gold coins"

               Alice> drop gold coins
               Alice sees "a gold coin"
               """)
    end

    test "the plural finds a single one" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given !object/gold_coin! in !room/bakery!

               Alice> get gold coins
               Alice sees "You pick up a gold coin"
               """)
    end

    test "a thing can be put straight into a player's hands" do
      assert {:ok, _} =
               play("""
               given Alice in !room/bakery!
               given 5 !object/gold_coin! in Alice

               Alice> look
               Alice does not see "gold coin"
               """)
    end

    test "an unknown prototype is named" do
      assert {:failed, [failure]} =
               play("given 3 !object/nonesuch! in !room/bakery!\n")

      assert failure.message =~ "no entity with the key !object/nonesuch!"
    end

    test "an unknown destination is named" do
      assert {:failed, [failure]} =
               play("given 3 !object/gold_coin! in !room/nowhere!\n")

      assert failure.message =~ "nowhere called !room/nowhere!"
    end
  end

  describe "expectations that don't hold" do
    test "a missing message fails and shows what arrived" do
      assert {:failed, [failure]} =
               play("""
               given Alice in !room/bakery!

               Alice> look
               Alice sees "a submarine periscope"
               """)

      assert failure.message =~ "Alice did not see it"
      assert failure.source == ~s|Alice sees "a submarine periscope"|
      assert failure.received != []
      assert Enum.any?(failure.received, &String.contains?(&1, "bakery"))
    end

    test "a message that should not have arrived fails" do
      assert {:failed, [failure]} =
               play("""
               given Alice in !room/bakery!

               Alice> look
               Alice does not see "bakery"
               """)

      assert failure.message =~ "should not have"
    end

    test "playing continues past a failure" do
      assert {:failed, failures} =
               play("""
               given Alice in !room/bakery!

               Alice> look
               Alice sees "definitely not there"

               Alice> look
               Alice sees "also not there"
               """)

      assert length(failures) == 2
    end

    test "a room that doesn't exist is named" do
      assert {:failed, [failure]} = play("given Alice in !room/nowhere!\n")

      assert failure.message =~ "no entity with the key !room/nowhere!"
    end

    test "using a player who never joined is explained" do
      assert {:failed, [failure]} = play("Zoe> look\n")

      assert failure.message =~ "Zoe has not joined"
      assert failure.message =~ "given Zoe in"
    end
  end

  describe "wait" do
    @moduletag :tmp_dir

    alias Pythelix.Game.Clock.Virtual
    alias Pythelix.Game.TickManager

    setup %{tmp_dir: dir} do
      # The scenario command line plays under the virtual clock; here the
      # application is already running on the real one, so switch for the
      # test's duration. The tick manager gets a fresh start afterwards, as
      # its timers were armed on a clock that no longer exists.
      start_supervised!(Virtual)
      Application.put_env(:pythelix, :clock, Virtual)

      on_exit(fn ->
        Application.delete_env(:pythelix, :clock)
        Supervisor.terminate_child(Pythelix.Supervisor, TickManager)
        Supervisor.restart_child(Pythelix.Supervisor, TickManager)
      end)

      fixture = Path.join(dir, "wheat.txt")

      File.write!(fixture, """
      !test/wheat!
      parent = "generic/object"
      singular = "a wheat seedling"
      location = "room/bakery"
      tick = 60
      grown = 0

      def on_tick(self):
          self.grown = self.grown + 1
          if self.grown >= 3:
              self.singular = "a stalk of ripe wheat"
          endif

      !test/oven!
      parent = "generic/object"
      singular = "a cold oven"
      location = "room/bakery"

      def light(self):
          self.singular = "a warm oven"

      !command/bake!
      parent = "generic/char_command"
      name = "bake"

      def run(character):
          realtime.now().add(30).schedule(!test/oven!, "light")
          character.msg("You light the oven.")
      """)

      [fixture: fixture]
    end

    test "ticks happen while a scenario waits", %{fixture: fixture} do
      assert {:ok, _} =
               play("""
               apply #{fixture}

               given Alice in !room/bakery!

               Alice> look
               Alice sees "a wheat seedling"

               wait 2m

               Alice> look
               Alice sees "a wheat seedling"

               wait 1m

               Alice> look
               Alice sees "a stalk of ripe wheat"
               """)
    end

    test "a scheduled call happens while a scenario waits", %{fixture: fixture} do
      assert {:ok, _} =
               play("""
               apply #{fixture}

               given Alice in !room/bakery!

               Alice> bake
               Alice sees "You light the oven."

               Alice> look
               Alice sees "a cold oven"

               wait 30s

               Alice> look
               Alice sees "a warm oven"
               """)
    end
  end

  describe "wait under the real clock" do
    test "is refused with an explanation" do
      assert {:failed, [failure]} = play("wait 3h\n")

      assert failure.message =~ "real clock"
      assert failure.message =~ "mix pythello.scenario"
    end
  end
end
