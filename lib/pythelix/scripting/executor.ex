defmodule Pythelix.Scripting.Executor do
  @moduledoc """
  Execute a script, handle pauses.
  """

  alias Pythelix.Method
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  def name(_), do: nil

  @doc """
  Executes a script.

  Args:

  * state: the state containing `method`, `args` and `kwargs`.

  """
  @spec execute(integer(), map()) :: {:ok, any()} | {:error, any()}
  def execute(executor_id, %{method: method, args: args, kwargs: kwargs}) do
    hub = :global.whereis_name(Pythelix.Command.Hub)
    Method.call(method, args, kwargs, "unknown")
    |> case do
      %Script{pause: wait_time} = script when wait_time != nil ->
        send(hub, {:executor_done, executor_id, :ok})
        Process.send_after(hub, {:"$gen_cast", {:unpause, self()}}, wait_time * 1000)
        {:keep, {script, method.code, "unknown"}}

      %Script{error: %Traceback{} = traceback} ->
        send(hub, {:executor_done, executor_id, :ok})
        {:error, traceback}

      script ->
        send(hub, {:executor_done, executor_id, :ok})
        {:ok, script}
    end
  end

  def handle_cast(:unpause, executor_id, {script, code, name}) do
    hub = :global.whereis_name(Pythelix.Command.Hub)

    %Script{script | cursor: script.cursor + 1, pause: nil}
    |> Script.execute(code, name)
    |> case do
      script = %Script{pause: wait_time} when wait_time != nil ->
        send(hub, {:executor_done, executor_id, :ok})
        Process.send_after(hub, {:"$gen_cast", {:unpause, self()}}, wait_time * 1000)
        {:noreply, {script, code, name}}

      %Script{error: %Traceback{} = traceback} = script ->
        send(hub, {:executor_done, executor_id, :ok})

        {:noreply, {script, code, name}}

      script ->
        send(hub, {:executor_done, executor_id, :ok})

        {:noreply, {script, code, name}}
    end
  end
end
