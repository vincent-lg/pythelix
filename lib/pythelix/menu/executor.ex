defmodule Pythelix.Menu.Executor do
  @moduledoc """
  Execute input inside a menu.

  The `Pythelix.Command.Hub` process is going to spawn tasks to
  run this menu input in another process.

  """

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script

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
    args = {menu, client, input, start_time, executor_id}
    call_input(args) || call_command(args)
  end

  defp call_input({menu, client, input, start_time, executor_id}) do
    case Scripting.Executor.run_method(menu, "input", [client, input]) do
      :nomethod ->
        call_command({menu, client, input, start_time, executor_id})

      {:ok, %Script{pause: :immediate, last_raw: value} = script} ->
        IO.inspect(value, label: "returned value")

        if value do
          call_command({menu, client, input, start_time, executor_id})
        else
          {:ok, script}
        end

      anything ->
        anything
    end
  end

  defp call_command({menu, client, input, start_time, executor_id}) do
    case String.split(input, " ", parts: 2) do
      [just_key] -> {just_key, ""}
      [cmd, str] -> {cmd, str}
    end
    |> handle_command_input(menu, client, start_time, executor_id)
    |> maybe_call_unknown_input(menu, client, start_time)
  end

  defp handle_command_input({cmd, args}, menu, client, start_time, executor_id) do
    commands = Record.get_attribute(menu, "commands", %{})
    command = Map.get(commands, cmd)

    if command == nil do
      {:nocommand, cmd, args}
    else
      process_args = {client, start_time, command, args}

      Pythelix.Command.Executor.execute(executor_id, process_args)
    end
  end

  defp maybe_call_unknown_input({:nocommand, cmd, args}, menu, client, _start_time) do
    input = "#{cmd} #{args}"

    case Scripting.Executor.run_method(menu, "unknown_input", [client, input]) do
      :nomethod ->
        Scripting.Executor.run_method(menu, "invalid_input", [client, input])

      anything ->
        anything
    end
  end

  defp maybe_call_unknown_input(anything, _menu, _client, _start_time), do: anything
end
