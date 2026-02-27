defmodule Mix.Tasks.Game.Epoch.Reset do
  use Mix.Task

  @shortdoc "Reset the game epoch to 0"

  def run(_args) do
    Pythelix.Task.GameEpochReset.run()
  end
end
