defmodule Pythelix.Method do
  @moduledoc """
  A Pythelix method on an entity.
  """

  alias Pythelix.Method
  alias Pythelix.Record
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Traceback

  @enforce_keys [:args, :code, :bytecode]
  defstruct [:args, :code, :bytecode]

  @type t() :: %{
          args: :free | list(),
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
  @spec call(t(), list(), Dict.t(), String.t(), list()) :: term() | :ok | {:error, binary()}
  def call(method, args, kwargs, name, opts \\ []) do
    with script <- fetch_script(method),
         {%Script{error: nil} = script, namespace} <- check_args(script, method, args, kwargs, name),
         %Script{error: nil} = script <- maybe_run(script, method, namespace, name) do
      (opts[:return] && script.last_raw) || script
    else
      {%Script{error: %Traceback{}} = script, _} -> script
      other -> other
    end
  end

  @doc """
  Calls a method from an entity.

  Args:
  * entity (Entity): the entity.
  * name (name): the method name.
  * args (list): the positional arguments (can be nil).
  * iwargs (Dict): the keyword arguments (can be nil).

  Returns:
    The returned result of the method or :nomethod, :noresult, :traceback.
  """
  @spec call_entity(Entity.t(), String.t(), list() | nil, Dict.t() | nil) :: term() | :nomethod | :noresult | :traceback
  def call_entity(entity, name, args \\ nil, kwargs \\ nil) do
    method_name = "#{inspect(entity)}, method #{name}"

    args = (args == nil && []) || args
    kwargs =
      case kwargs do
        %Dict{} -> kwargs
        map when is_map(map) -> Dict.new(map)
        nil -> Dict.new()
      end
      |> then(& Dict.put(&1, "self", entity))

    with %Method{} = method <- Record.get_method(entity, name),
         %Script{error: nil} = script <- Method.call(method, args, kwargs, method_name) do
      (script.last_raw == nil && :noresult) || script.last_raw
    else
      :nomethod ->
        :nomethod

      %Script{error: %Traceback{} = traceback} ->
        IO.puts(Traceback.format(traceback))
        :traceback
    end
  end

  def fetch_script(%Pythelix.Method{bytecode: bytecode}) do
    %Script{bytecode: bytecode}
  end

  defp check_args(%Script{} = script, %Method{} = method, args, kwargs, _name) do
    method.args
    |> then(fn
      :free ->
        {script, Dict.items(kwargs) |> Map.new()}

      constraints ->
        Namespace.validate(script, constraints, args, kwargs)
    end)
  end

  defp maybe_run(%Script{error: nil} = script, method, namespace, name) do
    %{script | cursor: 0}
    |> write_arguments(Enum.to_list(namespace))
    |> Script.execute(method.code, name)
  end

  defp maybe_run(%Script{} = script, _method, _namespace, _name), do: script

  defp write_arguments(%Script{} = script, []), do: script

  defp write_arguments(%Script{} = script, [{name, value} | rest]) do
    script
    |> Script.write_variable(name, value)
    |> write_arguments(rest)
  end
end
