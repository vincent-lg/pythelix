defmodule Pythelix.World.Executor do
  @moduledoc """
  Apply a worldlet directory or file.
  """

  alias Pythelix.World

  @doc """
  Returns the unique name for this task.
  """
  def name({_, {_task_id, _}}), do: nil

  @doc """
  Executes the task.

  Args:

  * state: the state containing `task_id` and `args` in a tuple.

  """
  @spec execute(integer(), map()) :: {:ok, any()} | {:error, any()}
  def execute(_executor_id, {_task_id, %{pid: pid, file: file}}) do
    send(pid, World.apply(file))

    {:ok, nil}
  end
end
