defmodule Pythelix.Menu.Executor do
  @moduledoc """
  Execute input inside a menu.

  The `Pythelix.Command.Hub` process is going to spawn tasks to
  run this menu input in another process.

  """

  alias Pythelix.Entity
  alias Pythelix.Record

  def name(_), do: nil

  def handle_cast(:unpause, executor_id, {script, code, name, task_id}) do
    Pythelix.Scripting.Executor.handle_cast(:unpause, executor_id, {script, code, name, task_id})
  end

  @doc """
  Executes user input.
  """
  @spec execute(integer(), map()) :: :ok
  def execute(executor_id, {menu, client, start_time, input}) do
    menu
    |> Record.get_entity()
    |> maybe_execute(client, input, start_time, executor_id)
  end

  defp maybe_execute(nil, _, _, _, _), do: {:error, "unknown menu"}

  defp maybe_execute(%Entity{} = menu, client, input, start_time, executor_id) do
    case String.split(input, " ", parts: 2) do
      [just_key] -> {just_key, ""}
      [cmd, str] -> {cmd, str}
    end
    |> handle_input(menu, client, start_time, executor_id)
  end

  defp handle_input({cmd, args}, menu, client, start_time, executor_id) do
    commands = Record.get_attribute(menu, "commands", %{})
    command = Map.get(commands, cmd)

    if command == nil do
      :ok
    else
      process_args = {client, start_time, command, args}

      Pythelix.Command.Executor.execute(executor_id, process_args)
    end
  end
end
