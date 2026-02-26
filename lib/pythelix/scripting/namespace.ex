defmodule Pythelix.Scripting.Namespace do
  @moduledoc """
  Defines a namespace, with methods and attributes, for an object.
  """

  alias Pythelix.{Entity, Record}
  alias Pythelix.Game.Modes
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Namespace
  alias Pythelix.Scripting.Object.{Dict, Duration, Password, Time}
  alias Pythelix.Scripting.Store
  alias Pythelix.Scripting.Traceback

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :attribute, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :function, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :method, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :attributes, persist: true)
      Module.register_attribute(__MODULE__, :functions, persist: true)
      Module.register_attribute(__MODULE__, :methods, persist: true)

      import Pythelix.Scripting.Namespace
      alias Pythelix.Scripting.Interpreter.Script
      alias Pythelix.Scripting.Store

      @before_compile Pythelix.Scripting.Namespace
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @attributes @attribute
                  |> Enum.map(fn name ->
                    aname =
                      case String.starts_with?(name, "attribute_") do
                        true -> String.slice(name, 10..-1//1)
                        false -> name
                      end

                    {aname, String.to_existing_atom("a_#{name}")}
                  end)
                  |> Map.new()
      @functions @function
                 |> Enum.map(fn name ->
                   fname =
                     case String.starts_with?(name, "function_") do
                       true -> String.slice(name, 9..-1//1)
                       false -> name
                     end

                   {fname, String.to_existing_atom("f_#{name}")}
                 end)
                 |> Map.new()
      @methods @method
               |> Enum.map(fn name ->
                 mname =
                   case String.starts_with?(name, "method_") do
                     true -> String.slice(name, 7..-1//1)
                     false -> name
                   end

                 {mname, String.to_existing_atom("m_#{name}")}
               end)
               |> Map.new()

      @doc false
      def attributes do
        @attributes
      end

      @doc false
      def functions do
        @functions
      end

      @doc false
      def methods do
        @methods
      end

      @doc false
      def getattr(script, self, name) do
        cond do
          attr = Map.get(attributes(), name) ->
            apply(__MODULE__, attr, [script, self])

          function = Map.get(functions(), name) ->
            %Callable{module: __MODULE__, object: nil, name: function}

          method = Map.get(methods(), name) ->
            %Callable{module: __MODULE__, object: self, name: method}

          true ->
            module_name =
              to_string(__MODULE__)
              |> String.split(".")
              |> Enum.at(-1)
              |> String.downcase()

            message = "'#{module_name}' doesn't have attribute '#{name}'"

            Script.raise(script, AttributeError, message)
        end
      end

      @doc false
      def setattr(script, _, _, _) do
        Traceback.raise(script, AttributeError, "can't set attribute")
        |> then(& {%{script | error: &1}, :none})
      end
    end
  end

  defmacro defattr({name, _, args}, do: block) do
    quote do
      @attribute to_string(unquote(name))
      def unquote(String.to_atom("a_#{name}"))(unquote_splicing(args)) do
        unquote(block)
      end
    end
  end

  defmacro defmet({name, _, args}, do: block) do
    quote do
      @method to_string(unquote(name))
      def unquote(String.to_atom("m_#{name}"))(unquote_splicing(args)) do
        unquote(block)
      end
    end
  end

  defmacro deffun({name, _, [_script, _namespace] = args}, constraints, do: block) do
    quote do
      @function to_string(unquote(name))
      def unquote(String.to_atom("f_#{name}"))(script, args, kwargs) do
        {script, namespace} =
          validate(script, unquote(constraints), args, kwargs)

        {unquote_splicing(args)} = {script, namespace}

        case script do
          %Script{error: %Traceback{}} ->
            {script, nil}

          _ ->
            unquote(block)
        end
      end
    end
  end

  defmacro defmet({name, _, [_script, _namespace] = args}, constraints, do: block) do
    quote do
      @method to_string(unquote(name))
      def unquote(String.to_atom("m_#{name}"))(script, self, args, kwargs) do
        {script, namespace} =
          validate(script, unquote(constraints), args, kwargs)

        namespace = Map.put(namespace, :self, self)
        {unquote_splicing(args)} = {script, namespace}

        case script do
          %Script{error: %Traceback{}} ->
            {script, nil}

          _ ->
            unquote(block)
        end
      end
    end
  end

  @doc """
  Locate the namespace matching a given value.
  """
  @spec locate(term()) :: module()
  def locate(value) do
    case value do
      {:sub_entity, _sub} -> Namespace.NewSubEntity
      atom when is_boolean(atom) -> Namespace.Bool
      :none -> Namespace.None
      :ellipsis -> Namespace.Ellipsis
      atom when is_atom(atom) -> atom
      int when is_integer(int) -> Namespace.Integer
      float when is_float(float) -> Namespace.Float
      list when is_list(list) -> Namespace.List
      str when is_binary(str) -> Namespace.String
      %Time{} -> Namespace.Time
      %Duration{} -> Namespace.Duration
      %Modes{} -> Namespace.GameModes
      %Format.String{} -> Namespace.String
      %Dict{} -> Namespace.Dict
      %Password{} -> Namespace.Password
      %MapSet{} -> Namespace.Set
      %Pythelix.Entity{} -> Namespace.Entity
      %Pythelix.SubEntity{} -> Namespace.SubEntity
      %Pythelix.Stackable{} -> Namespace.Stackable
    end
  end

  @doc """
  Call a method of this namespace.

  This method takes a script structure and returns it in any case.
  """
  def call(module, name, script, self, args \\ nil, kwargs \\ nil) do
    args = (args == nil && []) || args
    kwargs = (kwargs == nil && Dict.new()) || kwargs

    case Map.get(module.methods(), name) do
      nil -> {Script.raise(script, AttributeError, "unknown method #{name}"), :none}
      method -> apply(module, method, [script, self, args, kwargs])
    end
  end

  @doc """
  Validate constraints and fills out an argument map if valid.
  """
  def validate(script, constraints, args, kwargs) do
    constraints =
      constraints
      |> Enum.filter(fn {set, _} -> set != "self" end)

    args =
      args
      |> Stream.with_index()
      |> Stream.map(fn {arg, index} -> {index, arg} end)
      |> Map.new()

    {script, args, kwargs, namespace} =
      Enum.reduce(constraints, {script, args, kwargs, %{}}, &build_arg/2)

    script = check_signature(script, constraints, args, kwargs, namespace)

    {script, namespace}
  end

  def build_arg(constraint, {script, args, kwargs, namespace}) do
    {script, args, kwargs, value} =
      script
      |> enforce_arg_constraint(constraint, args, kwargs)

    {set, _} = constraint

    case value do
      :error ->
        {script, args, kwargs, namespace}

      _ ->
        namespace = Map.put(namespace, set, value)
        {script, args, kwargs, namespace}
    end
  end

  defp enforce_arg_constraint(script, {set, opts}, args, kwargs) do
    index = opts[:index]
    keyword = opts[:keyword]

    {from_pos, args} = (index && Map.pop(args, index)) || {nil, args}
    {from_keyword, kwargs} = (keyword && Dict.pop(kwargs, keyword)) || {nil, kwargs}

    cond do
      from_pos != nil && opts[:args] ->
        args =
          args
          |> Enum.sort_by(fn {key, _} -> key end)
          |> Enum.map(fn {_key, value} -> value end)
          |> then(& [from_pos | &1])

        {script, %{}, kwargs, args}

      opts[:kwargs] ->
        {script, args, Dict.new(), kwargs}

      from_pos != nil && from_keyword != nil ->
        # Positional arg takes priority over keyword (e.g. system-provided
        # entity overrides a same-named variable carried from refine scope).
        type = opts[:type]
        {script, value} = enforce_arg_type(script, set, from_pos, type)

        {script, args, kwargs, value}

      from_pos == nil and from_keyword == nil and Keyword.has_key?(opts, :default) ->
        value = Keyword.get(opts, :default)

        {script, args, kwargs, value}

      from_pos == nil and from_keyword == nil ->
        type = (index && "positional") || "keyword"
        message = "expected #{type} argument #{set}"

        {Script.raise(script, TypeError, message), args, kwargs, :error}

      true ->
        type = opts[:type]
        {script, value} = enforce_arg_type(script, set, (from_pos == nil && from_keyword) || from_pos, type)

        {script, args, kwargs, value}
    end
  end

  defp enforce_arg_type(script, name, ref, type) do
    type = (type == nil && :any) || type
    value = Store.get_value(ref, recursive: false)

    case check_arg_type(value, type) do
      {:error, message} ->
        message = "argument #{name} expects #{message}"

        Traceback.raise(script, TypeError, message)
        |> then(& {%{script | error: &1}, :error})

      :error ->
        message = "argument #{name} expects value of type #{inspect(type)}"

        Traceback.raise(script, TypeError, message)
        |> then(& {%{script | error: &1}, :error})

      _ ->
        {script, ref}
    end
  end

  defp check_arg_type(value, :any), do: value
  defp check_arg_type(%Format.String{} = value, :str), do: value
  defp check_arg_type(value, :str) when is_binary(value), do: value
  defp check_arg_type( value, :int) when is_integer(value), do: value
  defp check_arg_type(value, :float) when is_float(value), do: value
  defp check_arg_type(true, :bool), do: true
  defp check_arg_type(false, :bool), do: false
  defp check_arg_type(value, :list) when is_list(value), do: value
  defp check_arg_type(%MapSet{} = value, :set), do: value
  defp check_arg_type(%Dict{} = value, :dict), do: value

  defp check_arg_type(%Entity{} = entity, :entity), do: entity
  defp check_arg_type(_, :entity), do: {:error, "an entity"}

  defp check_arg_type(entity, {:entity, parent_key}) when is_binary(parent_key) do
    case entity do
      %Entity{} ->
        ancestors = Record.get_ancestors(entity)

        if Enum.any?(ancestors, & &1.key == parent_key) do
          entity
        else
          {:error, "an entity inhering from !#{parent_key}!"}
        end

      _ ->
        {:error, "an entity"}
    end
  end

  defp check_arg_type(_value, _), do: :error

  defp check_signature(script, constraints, args, kwargs, namespace) do
    check_signature_positional_args(script, constraints, args, namespace)
    |> check_signature_keyword_args(constraints, kwargs, namespace)
  end

  defp check_signature_positional_args(script, constraints, args, namespace) do
    all_args = Enum.any?(constraints, fn {_set, opts} -> opts[:args] end)
    map_constraints =
      constraints
      |> Stream.filter(fn {set, opts} -> opts[:index] && !opts[:args] && set != "self" end)
      |> Map.new()

    received =
      if all_args do
        length(constraints)
      else
        namespace
        |> Map.keys()
        |> Stream.map(fn key -> {key, Map.get(map_constraints, key)} end)
        |> Enum.reject(fn {_key, opts} -> opts == nil end)
        |> Enum.concat(Map.keys(args))
        |> length()
      end

    constraints =
      constraints
      |> Enum.filter(fn {set, opts} -> set != "self" && opts[:index] end)

    needed = length(constraints)

    if needed < received do
      message = "expected at most #{needed} arguments, got #{received}"

      Script.raise(script, TypeError, message)
    else
      script
    end
  end

  defp check_signature_keyword_args(%Script{error: nil} = script, constraints, kwargs, _namespace) do
    all_kwargs = Enum.any?(constraints, fn {_set, opts} -> opts[:kwargs] end)
    map_constraints =
      constraints
      |> Stream.filter(fn {_set, opts} -> opts[:keyword] && !opts[:kwargs] end)
      |> Map.new()

    missing =
      kwargs
      |> Dict.delete("self")
      |> Dict.items()
      |> Stream.filter(fn {name, _value} -> {name, Map.get(map_constraints, name)} end)
      |> Stream.reject(fn {_name, value} -> value == nil end)
      |> Enum.map(fn {name, _value} -> name end)

    if !all_kwargs && length(missing) > 0 do
      name = Enum.at(missing, 0)
      message = "this callable doesn't accept the #{name} keyword argument"

      Script.raise(script, TypeError, message)
    else
      script
    end
  end

  defp check_signature_keyword_args(script, _, _, _), do: script
end
