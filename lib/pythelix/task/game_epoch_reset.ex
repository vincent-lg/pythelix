defmodule Pythelix.Task.GameEpochReset do
  @moduledoc """
  Task implementation to reset the game epoch to zero.
  """

  alias Pythelix.Game.Epoch

  def run do
    Application.ensure_all_started(:pythelix)
    Epoch.reset()
    IO.puts("Game epoch has been reset to 0.")
  end
end
