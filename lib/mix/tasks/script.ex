defmodule Mix.Tasks.Script do
  use Mix.Task

  @shortdoc "Interactive Pythelix script REPL"

  def run(_args) do
    Pythelix.Task.Script.run()
  end
end
