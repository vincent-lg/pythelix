defmodule Pythelix.Scripting.Interpreter.Script do
  @doc """
  A script structure, representing an ongoing execution.

  It has a cursor, a stack, a map of variables and, of course,
  a list of bytecodes to execute.
  """

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Callable.Method
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.{Debugger, Script, VM}
  alias Pythelix.Scripting.Traceback

  @enforce_keys [:bytecode]
  defstruct [
    :bytecode,
    cursor: 0,
    line: 1,
    stack: [],
    references: %{},
    variables: %{},
    bound: %{},
    last_raw: nil,
    pause: nil,
    error: nil,
    debugger: nil
  ]

  @typedoc "a script with bytecode"
  @type t() :: %Script{
          bytecode: list(),
          cursor: integer(),
          line: integer(),
          stack: list(),
          references: map(),
          variables: map(),
          bound: map(),
          last_raw: any(),
          pause: nil | integer() | float(),
          error: nil | Traceback.t(),
          debugger: nil | %Debugger{}
        }

  @doc """
  Write a variable in the script, overriding a variable of the same name.

  If the variable value should have a reference, creates one.
  """
  @spec write_variable(t(), binary(), term()) :: t()
  def write_variable(script, variable, value) do
    {script, value} = (references?(value) && reference(script, value)) || {script, value}

    script
    |> store(variable, value)
  end

  @doc """
  Update the reference value for an object.
  """
  @spec update_reference(Script.t(), reference(), term()) :: Script.t()
  def update_reference(%{references: references} = script, reference, value) do
    references = Map.put(references, reference, value)

    %{script | references: references}
    |> debug("ref #{inspect(reference)} set to #{inspect(value)}")
    |> update_bound(reference, value)
  end

  @doc """
  Gets the value of a variable.

  If the variable is a reference, recursively search for a value.
  """
  def get_variable_value(script, name) do
    Map.get(script.variables, name)
    |> reference_to_value(script)
  end

  @doc """
  Gets the value from a reference or value.
  """
  @spec get_value(Script.t(), term()) :: term()
  def get_value(script, reference) when is_reference(reference) do
    Map.get(script.references, reference)
  end

  def get_value(_script, other), do: other

  @doc """
  Updates entity references.

  This is used to "refresh" the script if time has passed and the entity references are staled.

  Args:

  * script (Script): the script to refresh.

  """
  @spec refresh_entity_references(t()) :: t()
  def refresh_entity_references(%Script{} = script) do
    script.references
    |> Enum.map(fn
      {reference, %Entity{} = entity} ->
        {reference, Record.get_entity(entity.key || entity.id)}

      {reference, other} ->
        {reference, other}
    end)
    |> Map.new()
    |> then(& %{script | references: &1})
  end

  @doc """
  Add a bound attribute.
  """
  @spec bind_attribute(t(), reference(), integer(), String.t()) :: t()
  def bind_attribute(script, reference, entity_id, attribute_name) do
    bound =
      script.bound
      |> Map.get(reference, MapSet.new())
      |> MapSet.put({entity_id, attribute_name})

    bound =
      script.bound
      |> Map.put(reference, bound)
      |> Map.put({entity_id, attribute_name}, reference)

    %{script | bound: bound}
  end

  @doc """
  Raises an exception.

  Args:

  * script (Script) tghe script.
  exception (atom): the exception.
  message (string): the message.
  """
  @spec raise(t(), atom(), String.t()) :: t()
  def raise(script, exception, message) do
    Traceback.raise(script, exception, message)
    |> then(& %{script | error: &1})
  end

  @doc """
  Execute the given script.
  """
  @spec execute(Script.t()) :: Script.t()
  def execute(script, code \\ nil, owner \\ nil) do
    script
    |> run(code, owner)
  end

  defp run(%{bytecode: bytecode} = script, code, owner) do
    bytecode
    |> Stream.with_index()
    |> Stream.map(fn {op, index} -> {index, op} end)
    |> Map.new()
    |> run_next_bytecode(script, code, owner)
  end

  defp run_next_bytecode(_, %{pause: value} = script, _code, _owner) when value != nil do
    script
  end

  defp run_next_bytecode(_, %{error: %Traceback{} = traceback} = script, code, owner) do
    Traceback.associate(traceback, code, owner)
    |> then(& %{script | error: &1})
  end

  defp run_next_bytecode(bytecode, %{cursor: cursor} = script, code, owner) do
    case Map.get(bytecode, cursor) do
      nil ->
        script

      op ->
        script =
          script
          |> move_ahead()
          |> VM.handle(op)

        run_next_bytecode(bytecode, script, code, owner)
    end
  end

  defp move_ahead(%Script{cursor: cursor} = script) do
    %{script | cursor: cursor + 1}
  end

  def put_stack(%{stack: stack} = script, value, :no_reference) do
    %{script | stack: [value | stack]}
    |> debug("in stack: #{inspect(value)}")
  end

  def put_stack(%{stack: stack} = script, {:formatted, string}) do
    formatted = Format.String.new(script, string)

    %{script | stack: [formatted | stack]}
    |> debug("in stack: #{inspect(formatted)}")
  end

  def put_stack(script, {:setattr, entity_id, name, value}) do
    value = Map.get(script.bound, {entity_id, name}, value)
    {script, value} = (references?(value) && reference(script, value)) || {script, value}

    if is_reference(value) do
      bind_attribute(script, value, entity_id, name)
      |> debug("bind entity[#{entity_id}].#{name} to #{inspect(value)}")
    else
      script
    end
  end

  def put_stack(%{stack: stack} = script, {:getattr, entity_id, name, value}) do
    value = Map.get(script.bound, {entity_id, name}, value)

    value =
      case value do
        {:extended, module, fun} -> {:extended, entity_id, module, fun}
        _ -> value
      end

    {script, value} = (references?(value) && reference(script, value)) || {script, value}

    script =
      %{script | stack: [value | stack]}
      |> debug("in stack: #{inspect(value)}")

    if is_reference(value) do
      bind_attribute(script, value, entity_id, name)
      |> debug("bind entity[#{entity_id}].#{name} to #{inspect(value)}")
    else
      script
    end
  end

  def put_stack(%{stack: stack} = script, value) do
    {script, value} = (references?(value) && reference(script, value)) || {script, value}

    %{script | stack: [value | stack]}
    |> debug("in stack: #{inspect(value)}")
  end

  def get_stack(script, retrieve \\ :value)

  def get_stack(%{stack: [first | next], references: references} = script, retrieve) do
    first =
      case retrieve do
        :value ->
          (is_reference(first) && Map.get(references, first)) || first

        :reference ->
          (is_reference(first) && {Map.get(references, first), first}) || {first, first}
      end

    script =
      script
      |> debug("from stack: #{inspect(first)}")

    {%{script | stack: next}, first}
  end

  def get_stack(script, _retrieve) do
    raise "stack is empty, #{inspect(script)}"
  end

  def store(%{variables: variables} = script, variable, value) do
    variables = Map.put(variables, variable, value)

    %{script | variables: variables}
    |> debug("store #{variable} = #{inspect(value)}")
  end

  def jump(script, line) do
    script =
      script
      |> debug("jump to #{line}")

    %{script | cursor: line}
  end

  def reference(%{references: references} = script, value) do
    reference = make_ref()
    references = Map.put(references, reference, value)

    script =
      script
      |> debug("create ref #{inspect(reference)} = #{inspect(value)}")

    {%{script | references: references}, reference}
  end

  def references?(value) when is_atom(value), do: false
  def references?(%Method{}), do: false
  def references?(%Callable{}), do: false
  def references?(value) when is_reference(value), do: false
  def references?(value) when is_number(value), do: false
  def references?(:none), do: false
  def references?(value) when is_boolean(value), do: false
  def references?(value) when is_binary(value), do: false
  def references?(value) when is_tuple(value), do: false
  def references?(_value), do: true

  def reference_to_value(value, script) when is_reference(value) do
    Map.get(script.references, value)
    |> reference_to_value(script)
  end

  def reference_to_value(value, script) when is_list(value) do
    Enum.map(value, fn element -> reference_to_value(element, script) end)
  end

  def reference_to_value(value, _script), do: value

  def update_bound(script, reference, value) do
    script.bound
    |> Map.get(reference, [])
    |> Enum.reduce(script, fn {entity_id, attribute}, script ->
      Pythelix.Record.set_attribute(entity_id, attribute, value)

      script
    end)
  end

  def debug(%{debugger: %Debugger{} = debugger} = script, text) do
    debugger = Debugger.add(debugger, script.cursor - 1, text)

    %{script | debugger: debugger}
  end

  def debug(script, _text), do: script
end
