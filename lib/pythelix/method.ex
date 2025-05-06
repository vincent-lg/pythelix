defmodule Pythelix.Method do
  @moduledoc """
  A Pythelix method on an entity.
  """

  alias Pythelix.Scripting.Interpreter.Script

  @enforce_keys [:name, :code]
  defstruct [:name, :code, script: nil]

  @type t() :: %{
          name: binary(),
          code: binary(),
          script: Script.t()
        }

  def new(name, code) do
    %Pythelix.Method{name: name, code: code}
  end

  @doc """
  Call a method with arguments.

  Arguments can be worth referencing, thit is the script's conern though.

  Args:

  * method: the method structure.
  * args: the method arguments (as a map).

  """
  @spec call(t(), map()) :: :ok | {:error, binary()}
  def call(method, args) do
    method
    |> maybe_fetch_script()
    |> maybe_run(args)
  end

  def maybe_fetch_script(%Pythelix.Method{script: nil} = method) do
    case Pythelix.Scripting.run(method.code, call: false) do
      {:ok, script} -> script
      error -> error
    end
  end

  def maybe_fetch_script(%Pythelix.Method{script: script}), do: script

  defp maybe_run({:error, _} = error, _args), do: error

  defp maybe_run(%Script{} = script, args) do
    %{script | cursor: 0}
    |> write_arguments(Map.to_list(args))
    |> IO.inspect(label: "script")
    |> Script.execute()
  end

  defp write_arguments(%Script{} = script, []), do: script

  defp write_arguments(%Script{} = script, [{name, value} | rest]) do
    script
    |> Script.write_variable(name, value)
    |> write_arguments(rest)
  end
end
