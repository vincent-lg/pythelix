defmodule Pythelix.Method do
  @moduledoc """
  A Pythelix method on an entity.
  """

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script

  @enforce_keys [:args, :code, :bytecode]
  defstruct [:args, :code, :bytecode]

  @type t() :: %{
          args: list(),
          code: binary(),
          bytecode: list(),
        }

  def new(args, code, bytecode \\ nil) do
    bytecode =
      if bytecode == nil do
        script = Scripting.run(code, call: false)
        script.bytecode
      else
        bytecode
      end

    %Pythelix.Method{args: args, code: code, bytecode: bytecode}
  end

  @doc """
  Call a method with arguments.

  Arguments can be worth referencing, thit is the script's conern though.

  Args:

  * method: the method structure.
  * args: the method positional arguments (as a list).
  * kwargs: the method keyword arguments (as a map).
  * name (string): the method name.

  """
  @spec call(t(), list(), map(), String.t()) :: :ok | {:error, binary()}
  def call(method, args, kwargs, name) do
    method
    |> fetch_script()
    |> run(args, kwargs, method.code, name)
  end

  def fetch_script(%Pythelix.Method{bytecode: bytecode}) do
    %Script{bytecode: bytecode}
  end

  defp run(%Script{} = script, _args, kwargs, code, name) do
    %{script | cursor: 0}
    |> write_arguments(Map.to_list(kwargs))
    |> Script.execute(code, name)
  end

  defp write_arguments(%Script{} = script, []), do: script

  defp write_arguments(%Script{} = script, [{name, value} | rest]) do
    script
    |> Script.write_variable(name, value)
    |> write_arguments(rest)
  end
end
