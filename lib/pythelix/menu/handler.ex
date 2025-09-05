defmodule Pythelix.Menu.Handler do
  @moduledoc """
  Handle menu input using the script runner and step system.
  """

  alias Pythelix.Command.Handler, as: CommandHandler
  alias Pythelix.{Entity, Method, Record}
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Runner

  require Logger

  @doc """
  Handle user input within a menu context.

  This function first tries to call the menu's input method, then
  falls back to command processing if the input method returns false
  or doesn't exist.

  The owner_entity parameter allows specifying a different entity context
  for the menu processing, used by game modes.
  """
  @spec handle(Entity.t(), map(), String.t(), integer(), Entity.t() | nil) :: :ok
  def handle(menu, client, input, start_time, owner_entity \\ nil) do
    # Handle empty input by sending prompt
    case String.trim(input) do
      "" ->
        send_menu_prompt(menu, client, owner_entity)

      _ ->
        process_menu_input(menu, client, input, start_time, owner_entity)
    end
  end

  @doc """
  Send the menu prompt to the client.
  """
  def send_menu_prompt(menu, client, owner_entity) do
    case Record.get_method(menu, "prompt") do
      :nomethod ->
        # No prompt method, send default prompt or nothing
        :ok

      prompt_method ->
        # Execute prompt method
        script = create_input_script(client, "", prompt_method, owner_entity)
        method_name = "#{inspect(menu)}, method prompt"
        Runner.run(script, prompt_method.code, method_name, sync: true)
    end
  end

  defp process_menu_input(menu, client, input, start_time, owner_entity) do
    case Record.get_method(menu, "input") do
      :nomethod ->
        # No input method, try commands directly
        try_command_processing(menu, client, input, start_time, owner_entity)

      input_method ->
        # Execute input method with step to handle its result
        script = create_input_script(client, input, input_method, owner_entity)
        step = {__MODULE__, :handle_input_completion, [menu, client, input, start_time, owner_entity]}
        method_name = "#{inspect(menu)}, method input"
        Runner.run(script, input_method.code, method_name, step: step, sync: true)
    end
  end

  @doc """
  Handle completion of the input method.
  """
  def handle_input_completion(:ok, script, menu, client, input, start_time, owner_entity) do
    result = script.last_raw

    case result do
      # Input method returned false - try command processing
      false ->
        try_command_processing(menu, client, input, start_time, owner_entity)

      # Input method returned true or anything else - input was handled
      _ ->
        log_performance(start_time)
    end
  end

  def handle_input_completion(:error, _script, menu, client, input, start_time, owner_entity) do
    # Input method failed, try unknown_input method
    handle_unknown_input(menu, client, input, start_time, owner_entity)
  end

  @doc """
  Try processing input as a command.
  """
  def try_command_processing(menu, client, input, start_time, owner_entity) do
    case parse_command_from_input(input, menu) do
      {:command, command_key, args} ->
        CommandHandler.start_command_execution(command_key, args, client, start_time, owner_entity)

      :no_command ->
        handle_unknown_input(menu, client, input, start_time, owner_entity)
    end
  end

  @doc """
  Handle unknown input (no matching command).
  """
  def handle_unknown_input(menu, client, input, start_time, owner_entity) do
    case Record.get_method(menu, "unknown_input") do
      :nomethod ->
        # Try invalid_input as fallback
        handle_invalid_input(menu, client, input, start_time, owner_entity)

      unknown_input_method ->
        # Execute unknown_input method asynchronously
        script = create_input_script(client, input, unknown_input_method, owner_entity)
        step = {__MODULE__, :handle_unknown_input_completion, [start_time]}
        method_name = "#{inspect(menu)}, method unknown_input"
        Runner.run(script, unknown_input_method.code, method_name, step: step, sync: true)
    end
  end

  @doc """
  Handle completion of unknown_input method.
  """
  def handle_unknown_input_completion(:ok, _script, start_time) do
    log_performance(start_time)
  end

  def handle_unknown_input_completion(:error, _script, start_time) do
    log_performance(start_time)
  end

  @doc """
  Handle invalid input (final fallback).
  """
  def handle_invalid_input(menu, client, input, start_time, owner_entity) do
    case Record.get_method(menu, "invalid_input") do
      :nomethod ->
        # Send generic error message
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "I don't understand that."})
        log_performance(start_time)

      invalid_input_method ->
        # Execute invalid_input method asynchronously
        script = create_input_script(client, input, invalid_input_method, owner_entity)
        step = {__MODULE__, :handle_invalid_input_completion, [start_time]}
        method_name = "#{inspect(menu)}, method invalid_input"
        Runner.run(script, invalid_input_method.code, method_name, step: step, sync: true)
    end
  end

  @doc """
  Handle completion of invalid_input method.
  """
  def handle_invalid_input_completion(:ok, _script, start_time) do
    log_performance(start_time)
  end

  def handle_invalid_input_completion(:error, _script, start_time) do
    log_performance(start_time)
  end

  defp create_input_script(client, input, method, owner_entity) do
    entity_for_script = owner_entity || client
    Method.fetch_script(method)
    |> Script.write_variable("client", entity_for_script)
    |> Script.write_variable("input", input)
  end

  defp parse_command_from_input(input, menu) do
    case String.split(input, " ", parts: 2) do
      [command_name] ->
        check_command_exists(menu, command_name, "")

      [command_name, args] ->
        check_command_exists(menu, command_name, args)
    end
  end

  defp check_command_exists(menu, command_name, args) do
    commands = Record.get_attribute(menu, "commands", %{})
    case Map.get(commands, command_name) do
      nil -> :no_command
      command_key -> {:command, command_key, args}
    end
  end

  defp log_performance(start_time) do
    if start_time != nil && Application.get_env(:pythelix, :show_stats, false) do
      elapsed = System.monotonic_time(:microsecond) - start_time
      Logger.debug("⏱️ Menu input processed in #{elapsed} µs")
    end
  end
end
