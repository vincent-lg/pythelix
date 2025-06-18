defmodule Pythelix.Command.Executor do
  @moduledoc """
  Execute a command.

  The `Pythelix.Command.Hub` process is going to spawn tasks to
  run this command in another process.

  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Traceback

  def name(_), do: nil

  @doc """
  Executes a command.

  The key should lead to the command (a virtual entity). Methods
  on this command will be run in the same process.

  Args:

  * {key: the command key, args: the command arguments in a map}

  """
  @spec execute(integer(), map()) :: :ok
  def execute(_, {client, start_time, key, args}) do
    key
    |> get_entity()
    |> maybe_execute(args, client, start_time)
  end

  defp get_entity(key), do: Record.get_entity(key)

  defp maybe_execute(nil, _, _, _), do: {:error, "unknown command"}

  defp maybe_execute(%Entity{} = command, command_args, client, start_time) do
    with {:ok, pattern} <- get_command_syntax(command),
         {:ok, parsed} <- parse_command_syntax(pattern, command_args),
         {:ok, refined} <- refine_command(command, parsed, client),
         {:ok, script} <- run_command(command, refined, client) do
      if start_time != nil && Application.get_env(:pythelix, :show_stats, false) do
        elapsed = System.monotonic_time(:microsecond) - start_time
        IO.puts("⏱️ Run in #{elapsed} µs")
      end

      {:ok, script}
    else
      {:keep, _} = wait ->
        wait

      :parse_error ->
        parse_error(command, command_args, client)

        {:ok, nil}

      {:mandatory, _} ->
        parse_error(command, command_args, client)

        {:ok, nil}

      :refine_error ->
        refine_error(command, command_args, client)

        {:ok, nil}

      {:error, %Traceback{} = traceback} ->
        IO.puts(Traceback.format(traceback))
        run_error(command, command_args, client)

        {:ok, nil}
    end
  end

  defp get_command_syntax(%Entity{} = command) do
    attributes = Record.get_attributes(command)

    Map.fetch!(attributes, "syntax_pattern")
    |> then(&({:ok, &1}))
  end

  defp parse_command_syntax(pattern, args) do
    case Pythelix.Command.Parser.parse(pattern, args) do
      {:error, _} -> :parse_error
      result -> result
    end
  end

  defp refine_command(command, args, client) do
    methods = Record.get_methods(command)

    case Map.get(methods, "refine") do
      nil ->
        {:ok, args}

      method ->
        run_method(method, Map.put(args, "client", client))
        |> maybe_extract_refined_args(args)
    end
  end

  defp maybe_extract_refined_args({:ok, script}, args) do
    args
    |> Enum.map(fn {name, _} ->
      case Script.get_variable_value(script, name) do
        nil -> {nil, nil}
        other -> {name, other}
      end
    end)
    |> Enum.reject(&(&1 == nil))
    |> Map.new()
    |> then(&({:ok, &1}))
  end

  defp maybe_extract_refined_args(_, _), do: :refine_error

  defp run_command(%Entity{} = command, args, client) do
    methods = Record.get_methods(command)

    case Map.get(methods, "run") do
      nil -> run_error(command, args, client)
      method -> run_method(method, Map.put(args, "client", client))
    end
  end

  defp run_method(%Method{} = method, args) do
    state = %{
      method: method,
      args: [],
      kwargs: Dict.new(args)
    }

    Pythelix.Scripting.Executor.execute(nil, state)
  end

  defp parse_error(%Entity{} = command, args, client) do
    methods = Record.get_methods(command)

    case Map.get(methods, "parse_error") do
      nil ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "The command failed in parsing. Please contact an administrator."})

      method ->
        run_method(method, args)
    end
  end

  defp refine_error(%Entity{} = command, args, client) do
    methods = Record.get_methods(command)

    case Map.get(methods, "refined_error") do
      nil ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "The command failed while being refined. Please contact an administrator."})

      method ->
        run_method(method, args)
    end
  end

  defp run_error(%Entity{} = command, args, client) do
    methods = Record.get_methods(command)

    case Map.get(methods, "run_error") do
      nil ->
        pid = Record.get_attribute(client, "pid")
        send(pid, {:message, "The command failed during run. Please contact an administrator."})

      method ->
        run_method(method, args)
    end
  end
end
