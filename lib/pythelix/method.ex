defmodule Pythelix.Method do
  @moduledoc """
  A Pythelix method on an entity.
  """

  alias Pythelix.{Entity, Method, Record}
  alias Pythelix.Scripting
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Store
  alias Pythelix.Scripting.Traceback

  require Logger

  @enforce_keys [:args, :code, :bytecode]
  defstruct [:args, :code, :bytecode, file: nil, line: nil, entity: nil]

  @typedoc """
  A method and, when it came from a worldlet, where it was defined.

  `file` is the worldlet path relative to the game directory (with forward
  slashes, whatever the platform), and `line` the line in that file of the
  first line of the method body. Both are `nil` for a method set from code,
  from the console or from an older database.

  `entity` is the ID or key of the entity the method is defined on, set when
  the method is cached. A child calling an inherited method runs the parent's
  method, and a traceback should say so.
  """
  @type t() :: %{
          args: :free | list(),
          code: binary(),
          bytecode: list(),
          file: binary() | nil,
          line: pos_integer() | nil,
          entity: binary() | integer() | nil
        }

  @doc """
  Build a method from its arguments and code.

  Options:

  * `:file` and `:line`: where the method is defined (see `t/0`).
  """
  def new(args, code, bytecode \\ nil, opts \\ []) do
    bytecode =
      if bytecode == nil do
        script = Scripting.run(code, id: "method", call: false)

        if script.error do
          raise "syntax error in method body: #{script.error.message}"
        end

        script.bytecode
      else
        bytecode
      end

    %Pythelix.Method{
      args: args,
      code: code,
      bytecode: bytecode,
      file: opts[:file],
      line: opts[:line]
    }
  end

  @doc """
  Name a method the way a traceback shows it: `!key!.name`, or `#id.name`
  for an entity without a key.

  Given the method itself, the entity named is the one defining it rather
  than the one it was called on, so that an inherited method points at the
  worldlet it was written in. `entity` is used when the method doesn't know
  where it was defined.
  """
  @spec label(t() | Entity.t() | binary() | integer(), String.t()) :: String.t()
  def label(entity_or_method, name)

  def label(%Method{entity: definer}, name) when definer != nil do
    label(Record.get_entity(definer) || definer, name)
  end

  def label(%Method{}, name), do: "<unknown>.#{name}"
  def label(%Entity{key: key}, name) when is_binary(key), do: "!#{key}!.#{name}"
  def label(%Entity{id: id}, name), do: "##{id}.#{name}"
  def label(key, name) when is_binary(key), do: "!#{key}!.#{name}"
  def label(id, name) when is_integer(id), do: "##{id}.#{name}"
  def label(_other, name), do: "<unknown>.#{name}"

  @spec label(t() | term(), Entity.t() | binary() | integer(), String.t()) :: String.t()
  def label(%Method{entity: definer} = method, _entity, name) when definer != nil do
    label(method, name)
  end

  def label(_method, entity, name), do: label(entity, name)

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
    with script <- fetch_script(method, opts),
         {%Script{error: nil} = script, namespace} <-
           check_args(script, method, args, kwargs, name),
         %Script{error: nil} = script <- maybe_run(script, method, namespace, name, opts) do
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
  @spec call_entity(Entity.t(), String.t(), list() | nil, Dict.t() | nil, keyword()) ::
          term() | :nomethod | :noresult | :traceback
  def call_entity(entity, name, args \\ nil, kwargs \\ nil, opts \\ []) do
    args = (args == nil && []) || args

    kwargs =
      case kwargs do
        %Dict{} -> kwargs
        map when is_map(map) -> Dict.new(map)
        nil -> Dict.new()
      end
      |> then(&Dict.put(&1, "self", entity))

    call_opts = if opts[:immediate], do: [immediate: true], else: []

    with %Method{} = method <- Record.get_method(entity, name),
         method_name = Method.label(method, entity, name),
         %Script{error: nil} = script <- Method.call(method, args, kwargs, method_name, call_opts) do
      result =
        case (script.last_raw == nil && :noresult) || script.last_raw do
          %Format.String{} = fstr -> Format.String.format(fstr)
          other -> other
        end

      Script.destroy(script)
      result
    else
      :nomethod ->
        :nomethod

      %Script{error: %Traceback{} = traceback} = script ->
        Logger.error("\n" <> Traceback.format(traceback))
        Script.destroy(script)
        :traceback
    end
  end

  def fetch_script(%Pythelix.Method{bytecode: bytecode} = method, opts \\ []) do
    script = %Script{
      id: opts[:owner] || Store.new_script(),
      bytecode: bytecode,
      origin: origin(method)
    }

    script =
      case opts[:parent] do
        %Script{} = parent -> Script.set_parent(script, parent)
        _ -> script
      end

    script =
      case opts[:step] do
        {module, function, args} when is_atom(module) and is_atom(function) and is_list(args) ->
          Script.set_step(script, module, function, args)

        {module, function} when is_atom(module) and is_atom(function) ->
          Script.set_step(script, module, function, [])

        _ ->
          script
      end

    script =
      if opts[:immediate] do
        %{script | immediate: true}
      else
        script
      end

    script
  end

  # Where the script's code lives, for tracebacks. A method set from code has
  # no file, and then there is nothing to point at.
  defp origin(%Method{file: file, line: line}) when is_binary(file) and is_integer(line) do
    %{file: file, line: line}
  end

  defp origin(_method), do: nil

  def check_args(%Script{} = script, %Method{} = method, args, kwargs, _name) do
    method.args
    |> then(fn
      :free ->
        {script, Dict.items(kwargs) |> Map.new()}

      constraints ->
        Namespace.validate(script, constraints, args, kwargs)
    end)
    |> then(fn {script, namespace} ->
      case Dict.get(kwargs, "self", :unset) do
        :unset -> {script, namespace}
        value -> {script, Map.put(namespace, "self", value)}
      end
    end)
  end

  defp maybe_run(%Script{error: nil} = script, method, namespace, name, _opts) do
    %{script | cursor: 0}
    |> write_arguments(Enum.to_list(namespace))
    |> Script.execute(method.code, name)
  end

  defp maybe_run(%Script{} = script, _method, _namespace, _name, _opts), do: script

  def write_arguments(%Script{} = script, []), do: script

  def write_arguments(%Script{} = script, [{name, value} | rest]) do
    script
    |> Script.write_variable(name, value)
    |> write_arguments(rest)
  end
end
