defmodule Pythelix.Scripting.Namespace.Module.Random do
  @moduledoc """
  Module defining the random module.
  """

  use Pythelix.Scripting.Namespace

  defmet random(script, _namespace), [] do
    {script, :rand.uniform()}
  end
end
