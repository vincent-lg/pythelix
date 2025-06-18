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
    call_input(args)
    |> then(& (&1 == false && call_command(args)) || &1)
  end

  defp call_input({menu, client, input, start_time, _executor_id}) do
    case Scripting.Executor.run_method(menu, "input", [client, input]) do
      :nomethod ->
        false

      {:ok, %Script{pause: :immediate, last_raw: value} = script} ->

        if value do
          false
        else
          log_performance(start_time)
          {:ok, script}
        end

      anything ->
        log_performance(start_time)
        anything
    end
  end

  defp call_command({menu, client, input, start_time, executor_id}) do
    case String.split(input, " ", parts: 2) do
      [just_key] -> {just_key, ""}
      [cmd, str] -> {cmd, str}
    end
    |> handle_command_input(menu, client, start_time, executor_id)
    |> maybe_call_unknown_input(menu, client, start_time, input)
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

  defp maybe_call_unknown_input({:nocommand, _cmd, _args}, menu, client, start_time, input) do
    case Scripting.Executor.run_method(menu, "unknown_input", [client, input]) do
      :nomethod ->
        log_performance(start_time)
        Scripting.Executor.run_method(menu, "invalid_input", [client, input])

      anything ->
        log_performance(start_time)
        anything
    end
  end

  defp maybe_call_unknown_input(anything, _menu, _client, _start_time, _input), do: anything

  defp log_performance(start_time) do
    if start_time != nil && Application.get_env(:pythelix, :show_stats, false) do
      elapsed = System.monotonic_time(:microsecond) - start_time
      IO.puts("⏱️ Run in #{elapsed} µs")
    end
  end
end
