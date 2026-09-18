defmodule Mix.Tasks.Pythello.Scenario do
  @shortdoc "play scenarios against the game and report what didn't hold"

  @moduledoc """
  Play scenarios — transcripts saying what should happen when someone plays.

      mix pythello.scenario                        # every scenario under scenarios/
      mix pythello.scenario scenarios/harvest.txt  # one scenario
      mix pythello.scenario scenarios/quests       # one directory

  A scenario reads like a session in a MUD client:

      given Alice in !farm/room/field!
      given Bob in !farm/room/field!

      Alice> harvest wheat
      Alice sees "You harvest a bundle of wheat."
      Bob sees "Alice bends down and harvests some wheat."

  Everything runs against a throwaway database, which is dropped afterwards,
  so scenarios never touch a real game. Exits with status 1 if any fails.

  See `docs/scenarios.md` for the whole vocabulary.
  """

  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(args) do
    Mix.Task.run("compile")

    Pythelix.Task.Scenario.prepare()

    case Pythelix.Task.Scenario.run(List.first(args)) do
      :ok -> :ok
      :error -> exit({:shutdown, 1})
    end
  end
end
