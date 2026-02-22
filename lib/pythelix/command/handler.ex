defmodule Pythelix.Command.Handler do
  @moduledoc """
  Handle command execution using the script runner and step system.
  """

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Method
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.{Runner, Store}

  require Logger

  @doc """
  Handle command input from a client.

  This function parses the command, validates arguments, and starts
  the command execution pipeline with the refine step.
  """
  @spec handle(String.t(), map(), Entity.t(), integer()) :: :ok
  def handle(input, client, menu, start_time) do
    case parse_command_input(input) do
      {command_name, args_string} ->
        case find_command(menu, command_name) do
          nil ->
            handle_unknown_command(client, command_name)

          command_key ->
            start_command_execution(command_key, args_string, client, start_time)
        end
    end
  end

  @doc """
  Start the command execution pipeline.

  The owner_entity parameter allows specifying a different entity context
  for the command execution, used by game modes.
  """
  @spec start_command_execution(String.t(), String.t(), map(), integer(), Entity.t() | nil) :: :ok
  def start_command_execution(command_key, args_string, client, start_time, owner_entity \\ nil) do
    case Record.get_entity(command_key) do
      nil ->
        send_error(client, "Unknown command")

      %Entity{} = command ->
        case parse_and_prepare_command(command, args_string, client, owner_entity) do
          {:ok, _args, script, _method_name} ->
            # Start with refine step if refine method exists
            case Record.get_method(command, "refine") do
              :nomethod ->
                execute_method(command, "run", script, client, start_time, owner_entity)

              refine_method ->
                # Execute refine method, copying parsed variables and filling any
                # missing parameters from the method signature's default values.
                refine_script = Method.fetch_script(refine_method, owner: script.id)
                script =
                  %{refine_script | variables: script.variables}
                  |> apply_method_defaults(refine_method)

                step = {__MODULE__, :handle_refine_completion, [command, client, start_time, owner_entity]}
                Runner.run(script, refine_method.code, "#{command_key}, method refine", step: step, sync: true)
            end

          {:error, reason} ->
            handle_command_error(command, args_string, client, reason, owner_entity)
        end
    end
  end

  @doc """
  Handle completion of the refine step.
  """
  def handle_refine_completion(:ok, script, command, client, start_time, owner_entity) do
    # Refine completed successfully, now execute run method with updated variables
    execute_method(command, "run", script, client, start_time, owner_entity)
  end

  def handle_refine_completion(:error, _script, command, client, _start_time, owner_entity) do
    # Refine failed, handle error
    handle_refine_error(command, "", client, owner_entity)
  end

  @doc """
  Execute a method (refine or run) for a command.
  """
  def execute_method(command, method_name, script, client, start_time, owner_entity) do
    case Record.get_method(command, method_name) do
      :nomethod ->
        if method_name == "run" do
          handle_run_error(command, "", client, owner_entity)
        end

      method ->
        step = case method_name do
          "run" -> {__MODULE__, :handle_run_completion, [client, start_time]}
          _ -> nil
        end

        relevant_vars = relevant_method_vars(script.variables, method)

        script =
          Method.fetch_script(method, owner: script.id)
          |> Method.check_args(method, [], Dict.new(relevant_vars), "#{command.key}, method #{method_name}")
          |> then(fn {method_script, namespace} ->
            Method.write_arguments(method_script, Enum.to_list(namespace))
          end)
          |> Script.write_variable("self", command)

        Runner.run(script, method.code, "#{command.key}, method #{method_name}", step: step, sync: true)
    end
  end

  @doc """
  Handle completion of the run step.
  """
  def handle_run_completion(:ok, _script, _client, start_time) do
    # Command completed successfully
    log_performance(start_time)
  end

  def handle_run_completion(:error, _script, _client, start_time) do
    # Command execution failed
    log_performance(start_time)
  end

  defp parse_command_input(input) do
    case String.split(input, " ", parts: 2) do
      [command] -> {command, ""}
      [command, args] -> {command, args}
    end
  end

  defp find_command(menu, command_name) do
    commands = Record.get_attribute(menu, "commands", %{})
    Map.get(commands, command_name)
  end

  defp parse_and_prepare_command(command, args_string, client, owner_entity) do
    with {:ok, pattern} <- get_command_syntax(command),
         {:ok, parsed_args} <- parse_command_arguments(pattern, args_string),
         {:ok, script} <- create_command_script(command, parsed_args, client, owner_entity) do
      method_name = "#{command.key}, command execution"
      {:ok, parsed_args, script, method_name}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_command_syntax(command) do
    case Record.get_attribute(command, "syntax_pattern") do
      nil -> {:ok, []}  # No syntax pattern means no arguments
      pattern -> {:ok, pattern}
    end
  end

  defp parse_command_arguments(pattern, args_string) do
    case Pythelix.Command.Parser.parse(pattern, args_string) do
      {:error, _} -> {:error, :parse_error}
      {:mandatory, _} -> {:error, :parse_error}
      {:ok, result} -> {:ok, result}
    end
  end

  defp create_command_script(_command, args, client, owner_entity) do
    script = %Script{id: Store.new_script, bytecode: []}
    entity_for_script = owner_entity || client
    final_args = Map.put(args, "client", entity_for_script)

    # Write arguments to script
    script = write_arguments_to_script(script, final_args)
    {:ok, script}
  end

  defp write_arguments_to_script(script, args) when is_map(args) do
    Enum.reduce(args, script, fn {name, value}, acc ->
      Script.write_variable(acc, name, value)
    end)
  end

  defp write_arguments_to_script(script, _args), do: script

  defp handle_command_error(command, args_string, client, :parse_error, owner_entity) do
    handle_parse_error(command, args_string, client, owner_entity)
  end

  defp handle_command_error(_command, _args_string, client, reason, _owner_entity) do
    send_error(client, "Command failed: #{inspect(reason)}")
  end

  defp handle_unknown_command(client, command_name) do
    pid = Record.get_attribute(client, "pid")
    send(pid, {:message, "Unknown command: #{command_name}"})
  end

  defp handle_parse_error(command, args, client, owner_entity) do
    entity_for_script = owner_entity || client
    case Record.get_method(command, "parse_error") do
      :nomethod ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "Invalid command arguments."})

      method ->
        # Execute parse_error method asynchronously
        %Script{id: Store.new_script, bytecode: method.bytecode}
        |> Script.write_variable("client", entity_for_script)
        |> Script.write_variable("args", args)
        |> Runner.run(method.code, "parse_error", sync: true)
    end
  end

  defp handle_refine_error(command, args, client, owner_entity) do
    entity_for_script = owner_entity || client
    case Record.get_method(command, "refine_error") do
      :nomethod ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "Command refinement failed."})

      method ->
        # Execute refine_error method asynchronously
        %Script{id: Store.new_script, bytecode: method.bytecode}
        |> Script.write_variable("client", entity_for_script)
        |> Script.write_variable("args", args)
        |> Runner.run(method.code, "refine_error", sync: true)
    end
  end

  defp handle_run_error(command, args, client, owner_entity) do
    entity_for_script = owner_entity || client
    case Record.get_method(command, "run") do
      :nomethod ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "Command has no run method."})

      _method ->
        case Record.get_method(command, "run_error") do
          :nomethod ->
            pid = Record.get_attribute(client, "pid")
            send(pid, {:message, "Command execution failed."})

          error_method ->
            # Execute run_error method asynchronously
            %Script{id: Store.new_script, bytecode: error_method.bytecode}
            |> Script.write_variable("client", entity_for_script)
            |> Script.write_variable("args", args)
            |> Runner.run(error_method.code, "run_error", sync: true)
        end
    end
  end

  defp send_error(client, message) do
    pid = Record.get_attribute(client, "pid")
    send(pid, {:message, message})
  end

  # Filter script variables to only those that are named parameters of the method.
  # This prevents extra variables (e.g., from refine) from causing "unexpected keyword
  # argument" errors when check_args validates the run method's signature.
  defp relevant_method_vars(variables, %Method{args: :free}), do: variables
  defp relevant_method_vars(variables, %Method{args: constraints}) do
    Map.take(variables, Enum.map(constraints, fn {name, _} -> name end))
  end

  # Write default values for any method parameters that are missing from the script.
  # This ensures optional parameters (e.g., `number=1`) are available as variables
  # when the refine code accesses them, even if the user omitted them from input.
  defp apply_method_defaults(script, %Method{args: :free}), do: script
  defp apply_method_defaults(script, %Method{args: constraints}) do
    Enum.reduce(constraints, script, fn {name, opts}, acc ->
      if !Map.has_key?(acc.variables, name) && Keyword.has_key?(opts, :default) do
        Script.write_variable(acc, name, Keyword.get(opts, :default))
      else
        acc
      end
    end)
  end

  defp log_performance(start_time) do
    if start_time != nil && Application.get_env(:pythelix, :show_stats, false) do
      elapsed = System.monotonic_time(:microsecond) - start_time
      Logger.debug("⏱️ Command executed in #{elapsed} µs")
    end
  end
end
