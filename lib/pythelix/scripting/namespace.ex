defmodule Pythelix.Scripting.Namespace do
  @moduledoc """
  Defines a namespace, with methods and attributes, for an object.
  """

  alias Pythelix.Entity
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Namespace
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
        Map.get(attributes(), name)
        |> case do
          nil ->
            method = Map.get(methods(), name)

            %Callable{module: __MODULE__, object: self, name: method}

          attribute ->
            apply(__MODULE__, attribute, [script, self])
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
      list when is_list(list) -> Namespace.List
      str when is_binary(str) -> Namespace.String
      %Pythelix.Entity{} -> Namespace.Entity
    end
  end

  @doc """
  Call a method of this namespace.

  This method takes a script structure and returns it in any case.
  """
  def call(module, name, script, self, reference, args \\ nil, kwargs \\ nil) do
    method = Map.get(module.methods(), name)

    apply(module, method, [script, self, reference, args, kwargs])
  end

  @doc """
  Validate constraints and fills out an argument map if valid.
  """
  def validate(script, constraints, args, kwargs) do
    {script, _, _, namespace} =
      Enum.reduce(constraints, {script, args, kwargs, %{}}, &build_arg/2)

    {script, namespace}
  end

  def build_arg(constraint, {script, args, kwargs, namespace}) do
    {script, value} =
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

    from_pos = (index && Enum.at(args, index)) || nil
    from_keyword = (keyword && Map.get(kwargs, keyword)) || nil

    cond do
      from_pos && from_keyword ->
        message =
          "positional argument #{index} has also been specified as keyword argument #{keyword}"

        Traceback.raise(script, TypeError, message)
        |> then(& {%{script | error: &1}, :error})

      from_pos == nil and from_keyword == nil and Keyword.has_key?(opts, :default) ->
        value = Keyword.get(opts, :default)

        {script, value}

      from_pos == nil and from_keyword == nil ->
        type = (index && "positional") || "keyword"
        message = "expected #{type} argument #{set}"

        Traceback.raise(script, TypeError, message)
        |> then(& {%{script | error: &1}, :error})

      true ->
        type = opts[:type]
        {script, value} = enforce_arg_type(script, set, from_pos || from_keyword, type)

        {script, value}
    end
  end

  defp enforce_arg_type(script, name, value, type) do
    case check_arg_type(script, value, type) do
      :error ->
        message = "argument #{name} expects value of type #{type}"

        Traceback.raise(script, TypeError, message)
        |> then(& {%{script | error: &1}, :error})

      valid ->
        {script, valid}
    end
  end

  defp check_arg_type(_, value, :any), do: value
  defp check_arg_type(_, %Format.String{} = value, :str), do: value
  defp check_arg_type(_, value, :str) when not is_binary(value), do: :error
  defp check_arg_type(_, value, :int) when not is_integer(value), do: :error
  defp check_arg_type(_, value, :float) when not is_float(value), do: :error

  defp check_arg_type(script, value, :entity) do
    entity = Script.get_value(script, value)

    case entity do
      %Entity{} -> value
      _ -> :error
    end
  end

  defp check_arg_type(_, value, _), do: value
end
