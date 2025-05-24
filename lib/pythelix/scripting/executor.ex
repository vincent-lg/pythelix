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
  def execute(_, %{method: method, args: args, kwargs: kwargs}) do
    Method.call(method, args, kwargs, "unknown")
    |> case do
      %Script{error: %Traceback{} = traceback} -> {:error, traceback}
      script -> {:ok, script}
    end
  end
end
