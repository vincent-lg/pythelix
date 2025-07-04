defmodule Pythelix.Scripting.Callable do
  @doc """
  A callable structure, representing a need to call a functio/method.
  """

  @enforce_keys [:module, :object, :name]
  defstruct [:module, :object, :name]

  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  @typedoc "a callable object in script"
  @type t() :: %Callable{
          module: module(),
          object: term(),
          name: String.t()
        }

  @doc """
  Call the namespace.
  """
  def call(script, method_or_callable, args \\ [], kwargs \\ nil)

  def call(%Script{} = script, {:extended, id_or_key, namespace, name}, args, kwargs) do
    kwargs = (kwargs == nil && Dict.new()) || kwargs
    entity = Record.get_entity(id_or_key)

    apply(namespace, name, [script, entity, args, kwargs])
  end

  def call(%Script{} = script, %Callable.Method{} = method, args, kwargs) do
    kwargs = (kwargs == nil && Dict.new()) || kwargs
    case Callable.Method.call(method, args, kwargs) do
      %Script{error: %Traceback{chain: chain} = traceback} = _script ->
        %{traceback | chain: [{script, nil, nil} | chain]}
        |> then(& {%{script | error: &1}, :none})

      %Script{pause: :immediately, last_raw: raw} ->
        {script, raw}

      _script ->
        {script, :none}
    end
  end

  def call(%Script{} = script, %Callable{} = callable, args, kwargs) do
    kwargs = (kwargs == nil && Dict.new()) || kwargs
    apply(callable.module, callable.name, find_arguments(script, callable, args, kwargs))
  end

  @doc """
  Wraps and calls a method, returning its return value.

  Args:

  * script: the Pythello script.
  * object: the object of a Pythello-supported type.
  * name: the method name.
  * args: a list of arguments.
  * kwargs: a dictionary of keyword arguments.
  """
  @spec call!(Script.t(), term(), String.t(), list(), Dict.t()) :: term()
  def call!(%Script{} = script, object, name, args \\ [], kwargs \\ nil) do
    name = (is_binary(name) && String.to_existing_atom("m_#{name}")) || name

    module = Namespace.locate(object)
    callable = %Callable{module: module, object: object, name: name}

    call(script, callable, args, kwargs)
    |> then(fn
      {%Script{error: traceback}, _} when traceback != nil ->
        {:traceback, traceback}

      {script, value} ->
        Script.get_value(script, value)
    end)
  end

  defp find_arguments(%Script{} = script, %{object: nil}, args, kwargs) do
    [script, args, kwargs]
  end

  defp find_arguments(%Script{} = script, callable, args, kwargs) do
    [script, callable.object, args, kwargs]
  end
end
