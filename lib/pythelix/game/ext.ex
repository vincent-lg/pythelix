defmodule Pythelix.Game.Ext do
  @moduledoc """
  Global module that simply connects to the game hub and forwards job creation to it.
  This module is just here to redirect to the Game Hub.
  """

  use GenServer

  alias Pythelix.Game

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def run(job, server \\ __MODULE__) do
    GenServer.cast({:global, server}, {:run, job})
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:run, job}, state) do
    Game.Hub.run(job)
    {:noreply, state}
  end
end
