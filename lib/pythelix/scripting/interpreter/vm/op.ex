defmodule Pythelix.Scripting.Interpreter.VM.Op do
  @moduledoc """
  Grouping of frequent operations.
  """

  alias Pythelix.Scripting.{Callable, Namespace}
  alias Pythelix.Scripting.Interpreter.{Iterator, Script}
  alias Pythelix.Scripting.Namespace

  @modules %{
    "password" => Namespace.Module.Password,
    "random" => Namespace.Module.Random,
    "search" => Namespace.Module.Search
  }

  def put(script, value) do
    script
    |> Script.put_stack(value)
  end

  def op_not(script, nil) do
    {script, value} = Script.get_stack(script)

    script
    |> Script.put_stack(!value)
  end

  def read(%{variables: variables} = script, variable) do
    value =
      variables
      |> Map.get(variable, :no_var)
      |> then(fn
        :no_var -> Map.get(@modules, variable, :no_var)
        other -> other
      end)

    if value == :no_var do
      Script.raise(script, NameError, "name '#{variable}' is not defined")
    else
      script
      |> Script.put_stack(value)
    end
  end

  def getattr(script, attr) do
    {script, {value, self}} = Script.get_stack(script, :reference)

    namespace = Namespace.locate(value)

    case namespace.getattr(script, self, attr) do
      %Script{} = script ->
        script

      other ->
        script
        |> Script.put_stack(other)
    end
  end

  def setattr(script, name) do
    {script, {value, self}} = Script.get_stack(script, :reference)
    {script, {_, to_set}} = Script.get_stack(script, :reference)

    namespace = Namespace.locate(value)
    {script, result} = namespace.setattr(script, self, name, to_set)

    script
    |> Script.put_stack(result)
  end

  def builtin(script, name) do
    name = Map.get(Namespace.Builtin.functions(), name)

    script
    |> Script.put_stack(%Callable{module: Namespace.Builtin, object: nil, name: name})
  end

  def store(script, variable) do
    {script, {value, reference}} = Script.get_stack(script, :reference)
    value = reference || value

    Script.store(script, variable, value)
  end

  def mkiter(script, nil) do
    {script, value} = Script.get_stack(script)
    iterator = Iterator.new(script, value)

    script
    |> Script.put_stack(iterator)
  end

  def iter(script, line) do
    {script, {iterator, reference}} = Script.get_stack(script, :reference)

    case Iterator.next(script, reference, iterator) do
      :stop ->
        Script.jump(script, line)

      {:cont, script, value} ->
        script
        |> Script.put_stack(reference)
        |> Script.put_stack(value)
    end
  end

  def call(script, len) do
    {script, args} =
      if len > 0 do
        Enum.reduce(1..len, {script, []}, fn _, {script, values} ->
          {script, {_, ref}} = Script.get_stack(script, :reference)

          {script, [ref | values]}
        end)
      else
        {script, []}
      end

    {script, kwargs} = Script.get_stack(script)
    {script, callable} = Script.get_stack(script)

    {script, value} = Callable.call(script, callable, args, kwargs)

    script
    |> Script.put_stack(value)
  end

  def wait(script, nil) do
    {script, wait_time} = Script.get_stack(script)

    %{script | pause: wait_time}
  end

  def return(script, nil) do
    {script, {_, return_value}} = Script.get_stack(script, :reference)

    %{script | pause: :immediately, last_raw: return_value}
  end

  def raw(script, nil) do
    {script, {_, value}} = Script.get_stack(script, :reference)

    %{script | last_raw: value}
  end

  def pop(script, nil) do
    {script, _} = Script.get_stack(script)

    script
  end

  def line(script, line) do
    %{script | line: line}
  end
end
