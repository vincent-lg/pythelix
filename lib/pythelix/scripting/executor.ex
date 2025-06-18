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
      {:error, "task #{task_id} wasn't found"}
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
          {:ok, script}

        %Script{error: %Traceback{} = traceback} ->
          IO.puts(Traceback.format(traceback))
          Pythelix.Task.Persistent.del(task.id)
          {:error, "traceback"}

        _script ->
          Pythelix.Task.Persistent.del(task.id)
          {:ok, script}
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
        Pythelix.Task.Persistent.add(expire_at, name, method.code, script)
        {:ok, script}

      %Script{error: %Traceback{} = traceback} ->
        send(hub, {:executor_done, executor_id, :ok})
        {:error, traceback}

      script ->
        send(hub, {:executor_done, executor_id, :ok})
        {:ok, script}
    end
  end

  def execute(executor_id, %{method: _method, args: _args, kwargs: _kwargs} = state) do
    execute(executor_id, Map.put(state, :name, "unknown"))
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
