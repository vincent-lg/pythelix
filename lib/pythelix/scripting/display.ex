defmodule Pythelix.Scripting.Display do
  @moduledoc """
  Module holding helpers to display scripting objects.
  """

  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script

  @doc """
  Return the result of calling repr on an object.

  Args:
  * script: the script.
  * object: the object on which to call repr.
  """
  @spec repr(Script.t(), term()) :: String.t()
  def repr(script, object) do
    Callable.call!(script, object, "__repr__", [])
  end

  @doc """
  Return the result of calling __bool__ on an object.

  Args:
  * script: the script.
  * object: the object on which to call __bool__.
  """
  @spec to_bool(Script.t(), term()) :: boolean()
  def to_bool(script, object) do
    case Callable.call!(script, object, "__bool__", []) do
      {:traceback, _} ->
        # Fallback: if __bool__ is not defined, use the old behavior
        resolved = Pythelix.Scripting.Store.get_value(object)
        resolved != :none && resolved != false && resolved != nil

      value ->
        value
    end
  end

  @doc """
  Return the result of calling str on an object.

  Args:
  * script: the script.
  * object: the object on which to call str.
  """
  @spec str(Script.t(), term()) :: String.t()
  def str(script, object) do
    Callable.call!(script, object, "__str__", [])
  end
end
