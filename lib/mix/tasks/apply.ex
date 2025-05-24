defmodule Mix.Tasks.Apply do
  use Mix.Task

  @shortdoc "apply a worldlet directory or file"

  def run(args) do
    Pythelix.Task.Apply.run(args)
  end
end
