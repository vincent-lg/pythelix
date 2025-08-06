defmodule Pythelix.Execution.ScriptExecutor do
  @moduledoc """
  Handles script execution with nested method calls in the same process.
  
  This is the "heavy" execution context that can efficiently handle multiple
  nested method calls without spawning additional processes. It maintains
  the execution stack and manages pauses/resumptions within the same context.
  
  Key features:
  - Executes method chains in same process
  - Maintains call stack for nested calls
  - Handles script pauses and API call coordination
  - Manages parent-child script relationships
  - Integrates network and scripting packages seamlessly
  """
  
  use GenServer
  
  require Logger
  
  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Traceback
  alias Pythelix.Execution.PauseManager
  alias Pythelix.Task.Persistent, as: Task
  
  defstruct [
    :executor_id,
    :task_runner_pid,
    :call_stack,
    :current_script,
    :parent_context
  ]
  
  # Client API
  
  def start_link(executor_id, task, task_runner_pid) do
    GenServer.start_link(__MODULE__, {executor_id, task, task_runner_pid})
  end
  
  # Server Implementation
  
  def init({executor_id, task, task_runner_pid}) do
    state = %__MODULE__{
      executor_id: executor_id,
      task_runner_pid: task_runner_pid,
      call_stack: [],
      current_script: nil,
      parent_context: nil
    }
    
    # Execute the task immediately
    Process.send_after(self(), {:execute_task, task}, 0)
    
    {:ok, state}
  end
  
  def handle_info({:execute_task, task}, state) do
    result = execute_task(task, state)
    send(state.task_runner_pid, {:executor_completed, state.executor_id, result})
    {:stop, :normal, state}
  end
  
  # Task Execution
  
  defp execute_task({:command, client_id, start_time, command}, state) do
    client_key = "client/#{client_id}"
    client = Record.get_entity(client_key)
    menu = (client && Record.get_location_entity(client)) || nil
    
    if menu == nil do
      {:error, "no menu for client"}
    else
      execute_command(menu.key, client, start_time, command, state)
    end
  end
  
  defp execute_task({:menu_input, menu_key, client, input, start_time}, state) do
    menu = Record.get_entity(menu_key)
    
    if menu == nil do
      {:error, "unknown menu"}
    else
      execute_menu_input(menu, client, input, start_time, state)
    end
  end
  
  defp execute_task({:script_call, entity_key, method_name, args}, state) do
    entity = Record.get_entity(entity_key)
    
    if entity == nil do
      {:error, "unknown entity: #{entity_key}"}
    else
      execute_method_call(entity, method_name, args, state)
    end
  end
  
  defp execute_task({:script_resume, task_id}, state) do
    execute_script_resume(task_id, state)
  end
  
  # Command Execution
  
  defp execute_command(menu_key, client, start_time, input, state) do
    menu = Record.get_entity(menu_key)
    
    # Try menu input method first
    case execute_method_call(menu, "input", [client, input], state) do
      {:ok, %Script{pause: :immediate, last_raw: false}} ->
        # Menu input returned false, try commands
        execute_menu_command(menu, client, input, start_time, state)
        
      {:ok, %Script{} = script} ->
        handle_script_result(script, state)
        
      :nomethod ->
        # No input method, try commands directly
        execute_menu_command(menu, client, input, start_time, state)
        
      error ->
        error
    end
  end
  
  defp execute_menu_command(menu, client, input, start_time, state) do
    case String.split(input, " ", parts: 2) do
      [command_name] -> {command_name, ""}
      [command_name, args] -> {command_name, args}
    end
    |> find_and_execute_command(menu, client, start_time, state)
  end
  
  defp find_and_execute_command({command_name, args}, menu, client, start_time, state) do
    commands = Record.get_attribute(menu, "commands", %{})
    
    case Map.get(commands, command_name) do
      nil ->
        # No command found, try unknown_input
        case execute_method_call(menu, "unknown_input", [client, input], state) do
          :nomethod ->
            execute_method_call(menu, "invalid_input", [client, input], state)
          result ->
            result
        end
        
      command_key ->
        execute_command_entity(command_key, args, client, start_time, state)
    end
  end
  
  defp execute_command_entity(command_key, args, client, start_time, state) do
    command = Record.get_entity(command_key)
    
    if command == nil do
      {:error, "unknown command: #{command_key}"}
    else
      with {:ok, pattern} <- get_command_syntax(command),
           {:ok, parsed} <- parse_command_syntax(pattern, args),
           {:ok, refined} <- refine_command(command, parsed, client, state),
           {:ok, script} <- run_command(command, refined, client, state) do
        log_performance(start_time)
        handle_script_result(script, state)
      else
        :parse_error ->
          execute_method_call(command, "parse_error", [client, args], state)
          
        :refine_error ->
          execute_method_call(command, "refine_error", [client, args], state)
          
        error ->
          error
      end
    end
  end
  
  # Method Execution (Core of same-process execution)
  
  defp execute_method_call(entity, method_name, args, state) do
    case Record.get_method(entity, method_name) do
      :nomethod ->
        :nomethod
        
      %Method{} = method ->
        execute_method(method, args, entity, state)
    end
  end
  
  defp execute_method(%Method{} = method, args, entity, state) do
    # Prepare arguments with 'self' reference
    kwargs = case args do
      %Dict{} -> Dict.put(args, "self", entity)
      map when is_map(map) -> Dict.new(Map.put(map, "self", entity))
      list when is_list(list) -> Dict.new(%{"self" => entity})
      _ -> Dict.new(%{"self" => entity})
    end
    
    # Execute method directly (this is where same-process magic happens)
    script_state = %{
      method: method,
      args: [],
      kwargs: kwargs
    }
    
    script = Method.call(method, [], kwargs, "#{inspect(entity)}.#{method.name}")
    handle_script_result(script, state)
  end
  
  # Script Result Handling
  
  defp handle_script_result(%Script{pause: wait_time} = script, state) when wait_time != nil do
    # Script paused - register with PauseManager
    now = DateTime.utc_now()
    expire_at = DateTime.add(now, wait_time, :second)
    
    task_id = PauseManager.register_pause(expire_at, script, state.parent_context)
    Script.destroy(script)
    
    {:ok, :paused, task_id}
  end
  
  defp handle_script_result(%Script{error: %Traceback{} = traceback} = script, _state) do
    Logger.error("Script error: #{Traceback.format(traceback)}")
    Script.destroy(script)
    {:error, traceback}
  end
  
  defp handle_script_result(%Script{} = script, _state) do
    Script.destroy(script)
    {:ok, :completed}
  end
  
  # Script Resume Execution
  
  defp execute_script_resume(task_id, state) do
    task = Task.get(task_id)
    
    if task == nil do
      {:error, "unknown task: #{task_id}"}
    else
      script = task.script
      Task.restore(task)
      
      resumed_script = %Script{script | cursor: script.cursor + 1, pause: nil}
      |> Script.execute(task.code, task.name)
      
      Task.del(task.id)
      handle_script_result(resumed_script, state)
    end
  end
  
  # Command Parsing Helpers
  
  defp get_command_syntax(%Entity{} = command) do
    attributes = Record.get_attributes(command)
    
    case Map.fetch(attributes, "syntax_pattern") do
      {:ok, pattern} -> {:ok, pattern}
      :error -> {:ok, ""}
    end
  end
  
  defp parse_command_syntax(pattern, args) do
    case Pythelix.Command.Parser.parse(pattern, args) do
      {:error, _} -> :parse_error
      result -> result
    end
  end
  
  defp refine_command(command, args, client, state) do
    case execute_method_call(command, "refine", [client | Map.values(args)], state) do
      :nomethod ->
        {:ok, args}
        
      {:ok, %Script{} = script} ->
        # Extract refined variables from script
        refined = args
        |> Enum.map(fn {name, _} ->
          case Script.get_variable_value(script, name) do
            nil -> {name, Map.get(args, name)}
            value -> {name, value}
          end
        end)
        |> Map.new()
        
        Script.destroy(script)
        {:ok, refined}
        
      _ ->
        :refine_error
    end
  end
  
  defp run_command(command, args, client, state) do
    case execute_method_call(command, "run", [client | Map.values(args)], state) do
      :nomethod ->
        {:error, "no run method"}
        
      result ->
        result
    end
  end
  
  # Menu Input Execution
  
  defp execute_menu_input(menu, client, input, start_time, state) do
    case execute_method_call(menu, "input", [client, input], state) do
      :nomethod ->
        # No input method, try commands
        execute_menu_command(menu, client, input, start_time, state)
        
      result ->
        log_performance(start_time)
        result
    end
  end
  
  # Utilities
  
  defp log_performance(start_time) when start_time != nil do
    if Application.get_env(:pythelix, :show_stats, false) do
      elapsed = System.monotonic_time(:microsecond) - start_time
      Logger.info("⏱️ Executed in #{elapsed} µs")
    end
  end
  
  defp log_performance(_), do: :ok
end