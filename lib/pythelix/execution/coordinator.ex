defmodule Pythelix.Execution.Coordinator do
  @moduledoc """
  Main coordination module for the new execution architecture.
  
  This module provides a clean API for other parts of the system to submit
  tasks and integrates with the existing system. It acts as a bridge between
  the old Hub-based system and the new TaskQueue/TaskRunner architecture.
  
  Key responsibilities:
  - Public API for task submission
  - Integration with existing network and menu systems
  - Backward compatibility during transition
  - Statistics and monitoring
  """
  
  alias Pythelix.Execution.{TaskQueue, TaskRunner}
  alias Pythelix.Record
  
  @doc """
  Submit a command from a client for execution.
  
  This is called by the network layer when a client sends input.
  """
  def execute_command(client_id, command_text) do
    start_time = System.monotonic_time(:microsecond)
    TaskRunner.submit_command(client_id, start_time, command_text)
  end
  
  @doc """
  Execute menu input from a client.
  
  This is called when a client sends input while in a menu context.
  """
  def execute_menu_input(client_id, input_text) do
    client_key = "client/#{client_id}"
    client = Record.get_entity(client_key)
    
    if client do
      menu = Record.get_location_entity(client)
      start_time = System.monotonic_time(:microsecond)
      
      if menu do
        TaskRunner.submit_menu_input(menu.key, client, input_text, start_time)
      else
        {:error, "no menu for client"}
      end
    else
      {:error, "unknown client"}
    end
  end
  
  @doc """
  Execute a script method call.
  
  This is used for cross-package integration (e.g., network calling scripting methods).
  """
  def execute_script_method(entity_key, method_name, args \\ []) do
    TaskRunner.submit_script_call(entity_key, method_name, args)
  end
  
  @doc """
  Get execution statistics.
  """
  def get_stats() do
    %{
      queue_size: TaskQueue.size(),
      queue_empty?: TaskQueue.empty?()
    }
  end
  
  @doc """
  Check if the execution system is busy.
  """
  def busy?() do
    not TaskQueue.empty?()
  end
  
  # Integration helpers for existing code
  
  @doc """
  Legacy compatibility: submit a task in the old format.
  
  This helps during transition from the old Hub system.
  """
  def legacy_submit_command(client_id, start_time, command) do
    TaskRunner.submit_command(client_id, start_time, command)
  end
  
  def legacy_submit_script(entity_key, method_name, args) do
    TaskRunner.submit_script_call(entity_key, method_name, args)
  end
  
  @doc """
  Initialize the execution system.
  
  This starts all the necessary processes in the right order.
  """
  def start_children() do
    children = [
      {TaskQueue, []},
      {TaskRunner, []},
      {Pythelix.Execution.PauseManager, []}
    ]
    
    # Return child specifications for supervisor
    children
  end
end