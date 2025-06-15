defmodule Pythelix.Scripting.Executor do
  @moduledoc """
  Execute a script, handle pauses.
  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Traceback

  require Logger

  def name(_), do: nil

  @doc """
  Executes a script.

  Args:

  * state: the state containing `method`, `args` and `kwargs` or `task_id`.

  """
  @spec execute(integer(), map()) :: {:ok, any()} | {:error, any()}
  def execute(executor_id, %{task_id: task_id}) do
    task = Pythelix.Task.Persistent.get(task_id)

    if task == nil do
      Logger.warning("Cannot run unknown task #{task_id}")
      {:ok, nil}
    else
      hub = :global.whereis_name(Pythelix.Command.Hub)
      script = task.script

      %Script{script | cursor: script.cursor + 1, pause: nil}
      |> Script.execute(task.code, task.name)
      |> case do
        script = %Script{pause: wait_time} when wait_time != nil ->
          send(hub, {:executor_done, executor_id, :ok})
          now = DateTime.utc_now()
          expire_at = DateTime.add(now, wait_time, :second)
          Pythelix.Task.Persistent.update(task.id, expire_at, :same, :same, script)
          {:keep, {script, task.code, task.name, task.id}}

        %Script{error: %Traceback{} = traceback} ->
          IO.puts(Traceback.format(traceback))
          Pythelix.Task.Persistent.del(task.id)
          {:ok, nil}

        _script ->
          Pythelix.Task.Persistent.del(task.id)
          {:ok, nil}
      end
    end
  end

  def execute(executor_id, %{method: method, args: args, kwargs: kwargs, name: name}) do
    hub = :global.whereis_name(Pythelix.Command.Hub)
    Method.call(method, args, kwargs, name)
    |> case do
      %Script{pause: wait_time} = script when wait_time != nil ->
        send(hub, {:executor_done, executor_id, :ok})
        now = DateTime.utc_now()
        expire_at = DateTime.add(now, wait_time, :second)
        task = Pythelix.Task.Persistent.add(expire_at, "unknown", method.code, script, update: true)
        {:keep, {script, method.code, "unknown", task.id}}

      %Script{error: %Traceback{} = traceback} ->
        send(hub, {:executor_done, executor_id, :ok})
        {:error, traceback}

      script ->
        send(hub, {:executor_done, executor_id, :ok})
        {:ok, script}
    end
  end

  def execute(executor_id, %{method: method, args: args, kwargs: kwargs}) do
    execute(executor_id, %{method: method, args: args, kwargs: kwargs, name: "unknown"})
  end

  def handle_cast(:unpause, executor_id, {script, code, name, task_id}) do
    hub = :global.whereis_name(Pythelix.Command.Hub)

    %Script{script | cursor: script.cursor + 1, pause: nil}
    |> Script.execute(code, name)
    |> case do
      script = %Script{pause: wait_time} when wait_time != nil ->
        now = DateTime.utc_now()
        expire_at = DateTime.add(now, wait_time, :second)

        task_id =
          if task_id != nil do
            Pythelix.Task.Persistent.update(task_id, expire_at, :same, :same, script)
            task_id
          else
            task = Pythelix.Task.Persistent.add(expire_at, name, code, script, update: true)
            task.id
          end

        send(hub, {:executor_done, executor_id, :ok})
        {:noreply, {script, code, name, task_id}}

      %Script{error: %Traceback{} = traceback} = script ->
        send(hub, {:executor_done, executor_id, :ok})
        IO.puts(Traceback.format(traceback))
        Pythelix.Task.Persistent.del(task_id)

        {:stop, :normal, {script, code, name, task_id}}

      script ->
        send(hub, {:executor_done, executor_id, :ok})
        Pythelix.Task.Persistent.del(task_id)

        {:noreply, {script, code, name, task_id}}
    end
  end

  def run_method(%Entity{} = entity, name, args \\ [], kwargs \\ nil) do
    method_name = "#{inspect(entity)}, method #{name}"

    args = (args == nil && []) || args
    kwargs =
      case kwargs do
        %Dict{} -> kwargs
        map when is_map(map) -> Dict.new(map)
        nil -> Dict.new()
      end
      |> then(& Dict.put(&1, "self", entity))

    case Record.get_method(entity, name) do
      :nomethod ->
        :nomethod

      %Method{} = method ->
        state = %{
          method: method,
          args: args,
          kwargs: kwargs,
          name: method_name
        }

        execute(nil, state)
    end
  end
end
