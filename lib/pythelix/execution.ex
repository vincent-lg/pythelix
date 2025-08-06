defmodule Pythelix.Execution do
  @moduledoc """
  New task execution system for Pythelix.
  
  This module replaces the complex Hub-based system with a cleaner architecture:
  
  ## Architecture Overview
  
  ```
  Client Input → TaskQueue → TaskRunner → ScriptExecutor
                     ↓         ↑              ↓
               PauseManager ←---┘         (same process)
                     ↑                       ↓
                Script Resumes        Nested Method Calls
  ```
  
  ## Key Components
  
  - **TaskQueue**: Simple FIFO queue for independent tasks
  - **TaskRunner**: Central coordinator ensuring single-threaded execution
  - **ScriptExecutor**: Heavy execution context for script chains
  - **PauseManager**: Handles script pauses and resumptions
  - **Coordinator**: Public API and integration layer
  
  ## Key Benefits
  
  1. **Simplified Architecture**: Clear separation of concerns
  2. **Efficient Execution**: Method chains run in same process
  3. **Conflict Prevention**: Single-threaded coordination
  4. **Clean Pausing**: Proper script pause/resume mechanics
  5. **Cross-Package Integration**: Network and scripting work together
  
  ## Usage
  
  For most use cases, use the Coordinator module:
  
  ```elixir
  # Execute a command
  Pythelix.Execution.Coordinator.execute_command(client_id, "look")
  
  # Execute menu input
  Pythelix.Execution.Coordinator.execute_menu_input(client_id, "north")
  
  # Call a script method (cross-package)
  Pythelix.Execution.Coordinator.execute_script_method("player/123", "on_disconnect", [])
  ```
  
  ## Migration from Hub
  
  This system is designed to coexist with the existing Hub during transition:
  
  1. New components use separate modules in `Pythelix.Execution.*`
  2. Coordinator provides compatibility layer
  3. Existing code can gradually migrate to new API
  4. No breaking changes to external interfaces
  """
  
  # Re-export main API
  defdelegate execute_command(client_id, command), to: Pythelix.Execution.Coordinator
  defdelegate execute_menu_input(client_id, input), to: Pythelix.Execution.Coordinator
  defdelegate execute_script_method(entity_key, method_name, args \\ []), to: Pythelix.Execution.Coordinator
  defdelegate get_stats(), to: Pythelix.Execution.Coordinator
  defdelegate busy?(), to: Pythelix.Execution.Coordinator
  
  @doc """
  Child specification for supervision tree.
  
  Add this to your application's supervision tree:
  
  ```elixir
  children = [
    # ... other children
    {Pythelix.Execution, []}
  ]
  ```
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
  
  def start_link(_opts) do
    Supervisor.start_link(
      Pythelix.Execution.Coordinator.start_children(),
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end