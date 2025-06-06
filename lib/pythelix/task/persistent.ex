defmodule Pythelix.Task.Persistent do
  @moduledoc """
  Module to store persistent tasks, to be restarted by the server."""
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Task.Persistent, as: Task

  require Logger

  @enforce_keys [:id, :expire_at, :script]
  defstruct [:id, :expire_at, :script]

  @typedoc "A persistent task"
  @type t() :: %{id: integer(), expire_at: nil | DateTime.t(), script: Script.t()}

  @cache :px_tasks

  @doc """
  Initializes the cache.
  """
  @spec init() :: :ok
  def init() do
    Cachex.put(@cache, :ids, [])
    Cachex.put(@cache, :status, %{})
    cache_path()

    :ok
  end

  @doc """
  Load all the tasks and reschedule them if need be.
  """
  @spec load() :: integer()
  def load() do
    Path.wildcard("#{get_path()}/*.task")
    |> Enum.map(&load_task/1)
    |> Enum.reject(& &1 == nil)
    |> Enum.reduce({get_status(), get_ids()}, fn task, {status, ids} ->
      task
      |> schedule()
      |> case do
        :ok -> {Map.put(status, task.id, :scheduled), [task.id | ids]}
        _ -> {Map.put(status, task.id, :error), ids}
      end
    end)
    |> then(fn {status, ids} ->
      Cachex.put(@cache, :status, status)
      Cachex.put(@cache, :ids, Enum.sort(ids))

      length(ids)
    end)
  end

  @doc """
  Add a new task bound to a script.

  Args:

  * expire_at (nil or DateTime): the expiration.
  * script (Script): the script to run.
  """
  @spec add(nil | DateTime.t(), Script.t()) :: t()
  def add(expire_at, script) do
    {id, ids} = find_free_id()
    status = get_status()

    task = %Task{id: id, expire_at: expire_at, script: script}
    save(task)
    schedule(task)
    ids = Enum.sort([id | ids])
    Cachex.put(@cache, :ids, ids)
    Cachex.put(@cache, :status, Map.put(status, id, :scheduled))

    task
  end

  @doc """
  Update an existing task.

  Foces a save on the task with the new expire_at and script.
  If the task does not exist, do nothing.
  """
  @spec update(integer(), nil | DateTime.t(), Script.t()) :: :ok | :notask
  def update(id, expire_at, script) do
    get(id)
    |> case do
      %Task{} = task->
        task = %{task | expire_at: expire_at, script: script}
        save(task)
        :ok

      nil ->
        :notask
    end
  end

  @doc """
  Deletes a task.
  """
  @spec del(integer()) :: :ok | :notask | {:error, atom()}
  def del(id) do
    get(id)
    |> case do
      %Task{} ->
        status = Map.delete(get_status(), id)
        ids =
          get_ids()
          |> Enum.reject(& &1 == id)

        Cachex.del(@cache, id)
        Cachex.put(@cache, :ids, ids)
        Cachex.put(@cache, :status, status)
        File.rm(get_task_path(id))

      nil
        -> :notask
    end
  end

  @doc """
  Get a given task by its ID.
  """
  @spec get(integer()) :: t() | nil
  def get(task_id) do
    {:ok, task} = Cachex.get(@cache, task_id)
    task
  end

  defp cache_path() do
    path =
      System.get_env("TASKS_PATH", "tasks")
      |> then(fn path ->
        System.get_env("RELEASE_ROOT", File.cwd!())
        |> Path.join(path)
      end)

    if !File.exists?(path) do
      File.mkdir_p!(path)
    end

    Cachex.put(@cache, :path, path)
  end

  defp get_path() do
    case Cachex.get(@cache, :path) do
      {:ok, nil} -> raise "persistent tasks path not set"
      {:ok, path} -> path
    end
  end

  defp get_task_path(task_id) do
    "#{get_path()}/#{task_id}.task"
  end

  defp get_status() do
    case Cachex.get(@cache, :status) do
      {:ok, nil} -> raise "persistent tasks status not set"
      {:ok, status} -> status
    end
  end

  defp get_ids() do
    case Cachex.get(@cache, :ids) do
      {:ok, nil} -> raise "persistent tasks IDs not set"
      {:ok, ids} -> ids
    end
  end

  defp load_task(path) do
    File.read(path)
    |> case do
      {:ok, content} -> load_binary(path, content)
      _ -> nil
    end
  end

  defp load_binary(path, content) do
    try do
      :erlang.binary_to_term(content)
    rescue
      ArgumentError ->
        Logger.error("Cannot load the persistent task in #{path}")
        nil
    end
  end

  defp schedule(task) do
    if task.expire_at do
      now = DateTime.utc_now()
      time =
        task.expire_at
        |> DateTime.diff(now, :millisecond)
        |> then(& (&1 > 0 && &1) || 0)

      hub = :global.whereis_name(Pythelix.Command.Hub)
      Process.send_after(hub, {:"$gen_cast", {:restart_paused, task.id}}, time)
      IO.puts("Task #{task.id} schedule in {time} ms")
    end

    :ok
  end

  def save(task) do
    Cachex.put(@cache, task.id, task)
    File.write!(get_task_path(task.id), :erlang.term_to_binary(task), [:write])
  end

  defp find_free_id(), do: find_free_id(1, get_ids())
  defp find_free_id(id, []), do: {id, []}
  defp find_free_id(id, [first | _] = ids) when id < first, do: {id, ids}
  defp find_free_id(id, ids), do: find_free_id(id + 1, ids)
end
