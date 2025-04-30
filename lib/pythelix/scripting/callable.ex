defmodule Pythelix.Scripting.Callable do
  @doc """
  A callable structure, representing a need to call a functio/method.
  """

  @enforce_keys [:module, :object, :name]
  defstruct [:module, :object, :name]

  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script

  @typedoc "a callable object in script"
  @type t() :: %Callable{
          module: module(),
          object: term(),
          name: String.t()
        }

  @doc """
  Call the namespace.
  """
  def call(script, method_or_callable, args \\ [], kwargs \\ %{})

  def call(%Script{} = script, {:extended, id_or_key, namespace, name}, args, kwargs) do
    entity = Record.get_entity(id_or_key)

    apply(namespace, name, [script, entity, args, kwargs])
  end

  def call(%Script{} = script, %Method{} = method, _args, kwargs) do
    case Method.call(method, kwargs) do
      :ok -> {script, :none}
      {:error, error} -> {%{script | error: error}, :none}
    end
  end

  def call(%Script{} = script, %Callable{} = callable, args, kwargs) do
    apply(callable.module, callable.name, find_arguments(script, callable, args, kwargs))
  end

  defp find_arguments(%Script{} = script, %{object: nil}, args, kwargs) do
    [script, args, kwargs]
  end

  defp find_arguments(%Script{} = script, callable, args, kwargs) do
    [script, callable.object, args, kwargs]
  end
end
