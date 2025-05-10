defmodule Pythelix.Scripting.Executor do
  @moduledoc """
  Execute a script, handle pauses.
  """

  alias Pythelix.Method
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  @doc """
  Executes a script.

  Args:

  * state: the state containing `method`, `args` and `kwargs`.

  """
  @spec execute(map()) :: {:ok, any()} | {:error, any()}
  def execute(%{method: method, args: _args, kwargs: kwargs}) do
    script =
      method
      |> Method.maybe_fetch_script()

    method = %{method | script: script}

    Method.call(method, kwargs)
    |> case do
      %Script{error: %Traceback{} = traceback} -> {:error, traceback}
      script -> {:ok, script}
    end
  end
end
