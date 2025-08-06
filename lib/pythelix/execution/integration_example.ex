defmodule Pythelix.Execution.IntegrationExample do
  @moduledoc """
  Examples showing how to integrate the new execution system.
  
  These examples demonstrate:
  - Replacing Hub calls with new Coordinator API
  - Network package integration
  - Script method calling patterns
  - Error handling and monitoring
  """
  
  alias Pythelix.Execution.Coordinator
  
  @doc """
  Example: Network client sends command
  
  OLD (Hub-based):
  ```elixir
  Pythelix.Command.Hub.send_command(client_id, start_time, command)
  ```
  
  NEW (Execution-based):
  """
  def handle_client_command(client_id, command_text) do
    Coordinator.execute_command(client_id, command_text)
  end
  
  @doc """
  Example: Menu input handling
  
  OLD (Hub-based):
  ```elixir
  # Complex menu executor spawning
  ```
  
  NEW (Execution-based):
  """
  def handle_menu_input(client_id, input_text) do
    case Coordinator.execute_menu_input(client_id, input_text) do
      :ok -> 
        :ok
      {:error, reason} -> 
        IO.puts("Menu input failed: #{reason}")
        :error
    end
  end
  
  @doc """
  Example: Cross-package method call (Network → Scripting)
  
  When a client disconnects, the network package needs to notify
  the player entity's disconnect method.
  """
  def handle_client_disconnect(client_id) do
    # Get player entity for this client
    client_key = "client/#{client_id}"
    client = Pythelix.Record.get_entity(client_key)
    
    if client do
      player_key = Pythelix.Record.get_attribute(client, "player")
      
      if player_key do
        # Call player's disconnect method
        Coordinator.execute_script_method(player_key, "on_disconnect", [client])
      end
    end
  end
  
  @doc """
  Example: Script calling another script method
  
  This happens within the same ScriptExecutor process, no queuing needed.
  Inside a script method, you can call other methods directly:
  
  ```python
  # In a script method:
  def some_method(self):
      result = other_entity.some_other_method(arg1, arg2)
      return result
  ```
  
  The ScriptExecutor handles this automatically without creating new processes.
  """
  
  @doc """
  Example: API call with pause
  
  When a script needs to make an HTTP request or database call:
  
  ```python
  # In a script method:
  def fetch_player_data(self, player_id):
      # This will pause the script and resume when API responds
      response = http_get(f"https://api.example.com/player/{player_id}")
      return response.json()
  ```
  
  The execution system handles this by:
  1. Script executor pauses and registers with PauseManager
  2. API call happens in background
  3. When API responds, PauseManager resumes the script
  4. Script continues with the response data
  """
  
  @doc """
  Example: Monitoring and statistics
  """
  def monitor_execution_system() do
    stats = Coordinator.get_stats()
    
    IO.puts("""
    Execution System Status:
    - Queue size: #{stats.queue_size}
    - Queue empty: #{stats.queue_empty?}
    - System busy: #{Coordinator.busy?()}
    """)
  end
  
  @doc """
  Example: Error handling patterns
  """
  def safe_command_execution(client_id, command) do
    try do
      Coordinator.execute_command(client_id, command)
    rescue
      exception ->
        IO.puts("Command execution failed: #{Exception.message(exception)}")
        # Log error, notify client, etc.
        :error
    end
  end
end