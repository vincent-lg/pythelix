defmodule Pythelix.Scripting.Interpreter.VM.Exception do
  @moduledoc """
  VM opcodes for exception handling: setup_try, pop_try, check_exc, end_try, raise, reraise.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  @doc """
  Push a handler frame onto the handler stack.
  The argument is the cursor position of the except block.
  """
  def setup_try(%{handlers: handlers} = script, target) do
    handler = %{target: target}
    %{script | handlers: [handler | handlers]}
  end

  @doc """
  Remove the topmost handler frame (try body completed without error).
  """
  def pop_try(%{handlers: [_ | rest]} = script, _) do
    %{script | handlers: rest}
  end

  @doc """
  Check if the current caught exception matches the given type.
  If it matches, continue execution (into the except body).
  If not, jump to the given target (next except clause or reraise).

  The argument is {exception_atom | nil, jump_target}.
  nil means bare except (catch all).
  """
  def check_exc(script, {handler_type, jump_target}) do
    exception = Map.get(script.variables, "__exception__")

    if Pythelix.Scripting.Exception.matches?(exception, handler_type) do
      script
    else
      Script.jump(script, jump_target)
    end
  end

  @doc """
  Clean up after try/except/else/finally block.
  Removes exception-related variables.
  """
  def end_try(script, _) do
    variables =
      script.variables
      |> Map.delete("__exception__")
      |> Map.delete("__exc_message__")
      |> Map.delete("__traceback__")

    %{script | variables: variables}
  end

  @doc """
  Raise an exception. Pops the message from the stack.
  The argument is the exception atom.

  Raises TypeError if the exception name is not a known exception type,
  mirroring Python's "exceptions must derive from BaseException".
  """
  def op_raise(script, exc_atom) do
    {script, message} = Script.get_stack(script)

    if Pythelix.Scripting.Exception.valid?(exc_atom) do
      message =
        case message do
          :none -> inspect(exc_atom)
          msg -> msg
        end

      Script.raise(script, exc_atom, message)
    else
      Script.raise(script, TypeError, "exceptions must derive from BaseException")
    end
  end

  @doc """
  Re-raise the current caught exception (when no handler matched).
  """
  def reraise(script, _) do
    case Map.get(script.variables, "__traceback__") do
      %Traceback{} = traceback ->
        %{script | error: traceback}

      _ ->
        Script.raise(script, RuntimeError, "no active exception to re-raise")
    end
  end
end
