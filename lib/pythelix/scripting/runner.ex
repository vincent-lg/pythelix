defmodule Pythelix.Scripting.Runner do
  @moduledoc """
  Script runner that handles script execution, pauses, and step management.

  This module provides a simple API for script execution that automatically
  handles pauses, persistent tasks, and step execution. It's designed to work
  with the game hub's fire-and-forget model.
  """

  alias Pythelix.Game.Hub
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback
  alias Pythelix.Task.Persistent, as: Task

  require Logger

  @doc """
  Run a script with optional parent and step information.

  This is the main entry point for script execution. The script will either
  complete immediately or pause and be saved as a persistent task.

  Options:
  - parent: %Script{} - the parent script that called this one
  - step: {module, function} - the next step to execute when this script completes
  """
  @spec run(Script.t(), String.t(), String.t(), keyword()) :: :ok
  def run(%Script{} = script, code, name, opts \\ []) when is_binary(code) do
    script =
      script
      |> maybe_set_parent(opts[:parent])
      |> maybe_set_step(opts[:step])
      |> then(& %{&1 | code: code, name: name})

    # For testing or when :sync option is provided, execute directly
    if opts[:sync] || Application.get_env(:pythelix, :sync_script_execution, false) do
      execute(script, code, name)
    else
      Hub.run({__MODULE__, :execute, [script, code, name]})
    end
  end

  @doc """
  Execute a script (called by the game hub).

  This function handles the actual script execution and decides whether
  to complete, pause, or handle errors.
  """
  def execute(script, code, name) do
    case Script.execute(script, code, name) do
      %Script{pause: :wait_child} ->
        :ok

      %Script{parent: %Script{} = parent, pause: :immediately, error: nil} = script_with_parent ->
        parent = Script.put_stack(parent, script_with_parent.last_raw)

        run(parent, parent.code, parent.name, sync: true)

      %Script{pause: wait_time, error: nil} = paused_script when is_integer(wait_time) or is_float(wait_time) ->
        # Script paused - save as persistent task and schedule continuation
        schedule_continuation(paused_script, code, name, wait_time)
        Script.destroy(paused_script)

      %Script{error: %Traceback{} = traceback} = failed_script ->
        traceback = Traceback.build_from_bottom(traceback)
        # Script had error - execute step with error status and clean up
        log_error(traceback)
        failed_script = look_for_next_step(failed_script, traceback)
        execute_next_step(failed_script, :error)
        Script.destroy(failed_script)

      completed_script ->
        # Script completed successfully - execute step and clean up
        execute_next_step(completed_script, :ok)
        Script.destroy(completed_script)
    end
  rescue
    exception ->
      Logger.error(Exception.format(:error, exception, __STACKTRACE__))

      if is_struct(script, Script), do: Script.destroy(script)
  end

  @doc """
  Resume a paused script from persistent task (called by the game hub).
  """
  def resume_task(task_id) do
    case Task.get(task_id) do
      nil ->
        Logger.warning("Cannot resume unknown task #{task_id}")

      task ->
        # Restore references and resume script
        Task.restore(task)
        resumed_script = %Script{task.script | pause: nil}

        case Script.execute(resumed_script, task.code, task.name) do
          %Script{parent: %Script{} = parent, pause: :immediately, error: nil} = script_with_parent ->
            parent = Script.put_stack(parent, script_with_parent.last_raw)

            run(parent, parent.code, parent.name, sync: true)
            cleanup_task(task.id)

          %Script{pause: wait_time, error: nil} = paused_script when is_integer(wait_time) or is_float(wait_time) ->
            # Script paused again - update persistent task
            update_persistent_task(task.id, paused_script, task.code, task.name, wait_time)
            Script.destroy(paused_script)

          %Script{error: %Traceback{} = traceback} = failed_script ->
            # Script failed - clean up and execute step
            traceback = Traceback.build_from_bottom(traceback)
            log_error(traceback)
            failed_script = look_for_next_step(failed_script, traceback)
            execute_next_step(failed_script, :error)
            cleanup_task(task.id)
            Script.destroy(failed_script)

          completed_script ->
            # Script completed - execute step and clean up
            execute_next_step(completed_script, :ok)
            cleanup_task(task.id)
            Script.destroy(completed_script)
        end
    end
  rescue
    exception ->
      Logger.error("Task resumption failed for task #{task_id}: " <> Exception.format(:error, exception, __STACKTRACE__))

      case Task.get(task_id) do
        %{script: _script} -> cleanup_task(task_id)
        _ -> Task.del(task_id)
      end
  end

  defp maybe_set_parent(script, %Script{} = parent), do: Script.set_parent(script, parent)
  defp maybe_set_parent(script, _), do: script

  defp maybe_set_step(script, {module, function, args}) when is_atom(module) and is_atom(function) and is_list(args) do
    Script.set_step(script, module, function, args)
  end
  defp maybe_set_step(script, {module, function}) when is_atom(module) and is_atom(function) do
    Script.set_step(script, module, function, [])
  end
  defp maybe_set_step(script, _), do: script

  defp schedule_continuation(script, code, name, wait_time) do
    now = DateTime.utc_now()
    expire_at = DateTime.add(now, trunc(wait_time * 1000), :millisecond)
    Task.add(expire_at, name, code, script)
  end

  defp update_persistent_task(task_id, script, code, name, wait_time) do
    now = DateTime.utc_now()
    expire_at = DateTime.add(now, trunc(wait_time * 1000), :millisecond)
    Task.update(task_id, expire_at, code, name, script)
  end

  defp execute_next_step(script, status) do
    case Script.get_step(script) do
      nil ->
        :ok
      _step ->
        # Execute step in the same process - it should be fast
        case Script.execute_step(script, status) do
          :no_step ->
            :ok

          {:error, error} ->
            Logger.error("Step execution failed: #{inspect(error)}")

          _result ->
            :ok
        end
    end
  end

  defp log_error(traceback) do
    Logger.error("\n" <> Traceback.format(traceback))
  end

  defp cleanup_task(task_id) do
    Task.del(task_id)
  end

  defp look_for_next_step(%Script{step: nil, parent: nil} = script, traceback), do: %{script | error: traceback}
  defp look_for_next_step(%Script{step: nil, parent: parent}, traceback), do: look_for_next_step(parent, traceback)
  defp look_for_next_step(%Script{} = script, traceback), do: %{script | error: traceback}
end
