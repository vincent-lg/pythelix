defmodule Mix.Tasks.Pythelix.Plugin do
  @shortdoc "install, update, inspect and package plugins"

  @moduledoc """
  Manage the game's plugins. See `docs/plugins.md`.

      mix pythelix.plugin list
      mix pythelix.plugin verify [key]
      mix pythelix.plugin install <key>[@version]
      mix pythelix.plugin update [key] [-f]
      mix pythelix.plugin remove <key> [-f]
      mix pythelix.plugin eject <key>
      mix pythelix.plugin package <key>
      mix pythelix.plugin scenario <key>

  A release does the same with `bin/plugin`. Exits with status 1 when a command
  fails, so that it can gate a build.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("compile")
    Mix.Task.run("app.config")

    case Pythelix.Task.Plugin.run(args) do
      :ok -> :ok
      :error -> exit({:shutdown, 1})
    end
  end
end
