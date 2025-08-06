# New Execution System Migration Guide

This document explains the new task execution architecture and how to migrate from the existing Hub-based system.

## Architecture Overview

The new system replaces the complex `Pythelix.Command.Hub` with a cleaner, more maintainable architecture:

```
OLD SYSTEM:
Client Input → Hub (complex, handles everything) → Various Executors

NEW SYSTEM:
Client Input → TaskQueue → TaskRunner → ScriptExecutor
                    ↓         ↑              ↓
              PauseManager ←---┘         (same process)
                    ↑                       ↓
               Script Resumes        Nested Method Calls
```

## Key Improvements

### 1. Simplified Task Management
- **TaskQueue**: Simple FIFO queue (replaces complex Hub queue logic)
- **TaskRunner**: Single-threaded coordinator (prevents conflicts)
- **ScriptExecutor**: Heavy execution context (efficient method chains)

### 2. Efficient Script Execution
- Scripts calling other methods run in the same process (no overhead)
- Only independent tasks create new processes
- Maintains execution context and call stack

### 3. Clean Pause/Resume
- **PauseManager**: Centralized pause handling
- Proper parent-child script relationships
- API calls don't freeze the entire game

### 4. Cross-Package Integration
- Network and scripting packages work together seamlessly
- Clean API for cross-package method calls
- No more tangled executor relationships

## Migration Steps

### Step 1: Install New System

Add to your supervision tree (in `application.ex`):

```elixir
children = [
  # ... existing children
  {Pythelix.Execution, []}
]
```

### Step 2: Update Network Layer

Replace Hub calls with Coordinator calls:

```elixir
# OLD
Pythelix.Command.Hub.send_command(client_id, start_time, command)

# NEW  
Pythelix.Execution.Coordinator.execute_command(client_id, command)
```

### Step 3: Update Menu Handling

```elixir
# OLD
# Complex menu executor spawning logic

# NEW
Pythelix.Execution.Coordinator.execute_menu_input(client_id, input)
```

### Step 4: Update Cross-Package Calls

```elixir
# OLD
# Complex Hub-based script calling

# NEW
Pythelix.Execution.Coordinator.execute_script_method(entity_key, method_name, args)
```

## API Reference

### Main Coordinator API

```elixir
# Execute client command
Pythelix.Execution.Coordinator.execute_command(client_id, command_text)

# Execute menu input
Pythelix.Execution.Coordinator.execute_menu_input(client_id, input_text)

# Call script method (cross-package integration)
Pythelix.Execution.Coordinator.execute_script_method(entity_key, method_name, args)

# Get system statistics
Pythelix.Execution.Coordinator.get_stats()

# Check if system is busy
Pythelix.Execution.Coordinator.busy?()
```

### Legacy Compatibility

For gradual migration, legacy methods are provided:

```elixir
# These work with the new system but use old-style parameters
Pythelix.Execution.Coordinator.legacy_submit_command(client_id, start_time, command)
Pythelix.Execution.Coordinator.legacy_submit_script(entity_key, method_name, args)
```

## Key Behavioral Changes

### 1. Same-Process Method Chains

**OLD**: Each method call spawned a new process
**NEW**: Method chains run in same ScriptExecutor process

```python
# In a script method - all run in same process:
def player_attack(self, target):
    weapon = self.get_weapon()          # Same process
    damage = weapon.calculate_damage()  # Same process  
    target.take_damage(damage)          # Same process
    return "Attack complete"
```

### 2. Simplified Pausing

**OLD**: Complex pause logic scattered across executors
**NEW**: Clean pause/resume through PauseManager

```python
# Script pauses are handled automatically:
def long_action(self):
    client.msg("Starting long action...")
    wait 5  # Pause for 5 seconds
    client.msg("Action complete!")
```

### 3. Clean Error Handling

**OLD**: Errors could propagate in confusing ways
**NEW**: Clean error boundaries at ScriptExecutor level

## Testing and Validation

### 1. Unit Tests

Test individual components:

```elixir
# Test TaskQueue
assert TaskQueue.empty?()
TaskQueue.enqueue({:test, :task})
assert {:ok, {:test, :task}} = TaskQueue.dequeue()

# Test Coordinator API
assert :ok = Coordinator.execute_command(1, "look")
```

### 2. Integration Tests

Test complete flows:

```elixir
# Test command execution flow
test "command execution flow" do
  client_id = setup_test_client()
  assert :ok = Coordinator.execute_command(client_id, "inventory")
  # Assert expected behavior
end
```

### 3. Performance Monitoring

Monitor the new system:

```elixir
stats = Coordinator.get_stats()
assert stats.queue_size < 100  # Ensure queue doesn't grow too large
assert stats.queue_empty? == true  # Ensure tasks complete quickly
```

## Rollback Plan

If issues arise, you can temporarily disable the new system:

1. Remove `{Pythelix.Execution, []}` from supervision tree
2. Re-enable Hub-based system
3. All existing code continues to work

## Benefits Summary

✅ **Simplified Architecture**: Clear separation of concerns  
✅ **Better Performance**: Same-process method chains  
✅ **Conflict Prevention**: Single-threaded coordination  
✅ **Clean Integration**: Network ↔ Scripting cooperation  
✅ **Proper Pausing**: Scripts can pause without freezing game  
✅ **Maintainable Code**: Each component has single responsibility  
✅ **Easy Migration**: Backward compatibility during transition  

## Support

For questions or issues during migration:

1. Check the integration examples in `integration_example.ex`
2. Review the individual module documentation
3. Test with small commands first before migrating complex flows
4. Use monitoring tools to verify system health

The new system is designed to be a drop-in replacement with significant improvements in maintainability and performance.