defmodule Pythelix.Menu.Connector do
  @moduledoc """
  Execute when a client connects.
  """

  alias Pythelix.Entity
  alias Pythelix.Record

  def name(_), do: nil

  def handle_cast(:unpause, executor_id, {script, code, name, task_id}) do
    Pythelix.Scripting.Executor.handle_cast(:unpause, executor_id, {script, code, name, task_id})
  end

  @doc """
  Executes connection.
  """
  @spec execute(integer(), map()) :: :ok
  def execute(executor_id, {client}) do
    client
    |> Record.get_entity()
    |> maybe_execute(executor_id)
  end

  defp maybe_execute(nil, _), do: {:ok, nil}

  defp maybe_execute(%Entity{} = client, _executor_id) do
    menu = Record.get_entity("menu/motd")
    Record.change_location(client, menu)
    {:ok, nil}
  end
end
