defmodule Mix.Tasks.Pythello.Check do
  @shortdoc "check worldlets for Pythello syntax errors, without a running server"

  @moduledoc """
  Check worldlets without applying them.

      mix pythello.check                    # every worldlet in the worldlets directory
      mix pythello.check worldlets/room.txt # one file
      mix pythello.check worldlets/quests   # one directory, recursively
      mix pythello.check --json             # machine-readable, for editors and tools

  Nothing is created, updated or saved, and no server has to be running: this
  only answers whether the worldlets parse. Use `mix apply` to apply them to a
  running game.

  Exits with status 1 when something is wrong, so it can gate a commit or a
  build.
  """

  use Mix.Task

  alias Pythelix.Task.Check

  @impl true
  def run(args) do
    # Compiling is enough: checking never reaches the cache or the database.
    Mix.Task.run("compile")

    case Check.run(args) do
      :ok -> :ok
      :error -> exit({:shutdown, 1})
    end
  end
end
