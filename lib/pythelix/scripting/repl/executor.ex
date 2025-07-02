defmodule Pythelix.Scripting.REPL.Executor do
  @moduledoc """
  Executes a script in a REPL.
  """

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  @doc """
  Returns the unique name for this task.
  """
  def name({_, {task_id, _}}) do
    {:via, Registry, {Registry.LongRunning, task_id}}
  end

  @doc """
  Executes the task.

  Args:

  * state: the state containing `task_id` and `args` in a tuple.

  """
  @spec execute(integer(), map()) :: {:ok, any()} | {:error, any()}
  def execute(executor_id, {_task_id, %{pid: _pid}}) do
    hub = :global.whereis_name(Pythelix.Command.Hub)
    send(hub, {:executor_done, executor_id, :ok})

    :keep
  end

  def handle_cast({:input, input}, executor_id, {task_id, %{script: script, pid: pid}}) do
    script = handle_input(script, input, pid)

    hub = :global.whereis_name(Pythelix.Command.Hub)
    send(hub, {:executor_done, executor_id, :ok})

    {:noreply, {task_id, %{script: script, pid: pid}}}
  end

  defp handle_input(script, "/s", pid) do
    output = inspect(script)
    send(pid, {:text, output})
  end

  defp handle_input(script, input, pid) do
    eval_start_time = System.monotonic_time(:microsecond)
    new_script = Scripting.run(input, call: false)
    eval_elapsed = System.monotonic_time(:microsecond) - eval_start_time

    script =
      case script do
        nil ->
          new_script

        old_script ->
          %{old_script | bytecode: new_script.bytecode, cursor: 0}
      end

    script = script
      |> Script.refresh_entity_references()

    exec_start_time = System.monotonic_time(:microsecond)
    case Scripting.Interpreter.Script.execute(script, input, "<stdin>") do
      %{error: %Traceback{} = traceback} ->
        output = Traceback.format(traceback)
        send(pid, {:text, output})
        script

      script ->
        exec_elapsed = System.monotonic_time(:microsecond) - exec_start_time

        apply_start_time = System.monotonic_time(:microsecond)
        Pythelix.Record.Diff.apply()
        apply_elapsed = System.monotonic_time(:microsecond) - apply_start_time

        output =
          if script.last_raw != nil && script.last_raw != :none do
            script
            |> Script.get_value(script.last_raw)
            |> inspect()
          else
            nil
          end

        send(pid, {:text, output, eval_elapsed, exec_elapsed, apply_elapsed})

        %{script | last_raw: nil}
    end
  end
end
