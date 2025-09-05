defmodule Pythelix.Scripting.Interpreter.Script do
  @doc """
  A script structure, representing an ongoing execution.

  It has a cursor, a stack, a map of variables and, of course,
  a list of bytecodes to execute.
  """

  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Callable.{Method, SubMethod}
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.{Debugger, Script, VM}
  alias Pythelix.Scripting.Object.Reference
  alias Pythelix.Scripting.Store
  alias Pythelix.Scripting.Traceback

  @enforce_keys [:id, :bytecode]
  defstruct [
    :id,
    :bytecode,
    cursor: 0,
    line: 1,
    stack: [],
    variables: %{},
    last_raw: nil,
    pause: nil,
    error: nil,
    debugger: nil,
    parent: nil,
    step: nil,
    code: "",
    name: "unknown"
  ]

  @typedoc "a script with bytecode"
  @type t() :: %Script{
          id: String.t(),
          bytecode: list(),
          cursor: integer(),
          line: integer(),
          stack: list(),
          variables: map(),
          last_raw: any(),
          pause: nil | :immediately | integer() | float(),
          error: nil | Traceback.t(),
          debugger: nil | %Debugger{},
          parent: nil | t(),
          step: nil | {atom(), atom(), list()},
          code: String.t(),
          name: String.t()
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
  Gets the value of a variable.

  If the variable is a reference, recursively search for a value.
  """
  def get_variable_value(script, name) do
    Map.get(script.variables, name)
    |> Store.get_value()
  end

  @doc """
  Raises an exception.

  Args:

  * script (Script) the script.
  * exception (atom): the exception.
  * message (string): the message.
  """
  @spec raise(t(), atom(), String.t()) :: t()
  def raise(script, exception, message, code \\ nil, owner \\ nil) do
    Traceback.raise(script, exception, message, code, owner)
    |> then(& %{script | error: &1})
  end

  @doc """
  Execute the given script.
  """
  @spec execute(Script.t()) :: Script.t()
  def execute(script, code \\ nil, owner \\ nil, _opts \\ []) do
    script
    |> run(code, owner)
  end

  @doc """
  Destroys the script, cleaning up references.
  Don't call this function for all created scripts: a script started
  from another will use the parent's ownership. But when the parent
  restarts, the references should still be around.
  """
  @spec destroy(t()) :: :ok
  def destroy(script) do
    Store.delete_by_owner(script.id)
    Store.delete_script(script.id)
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

  def put_stack(%{stack: stack} = script, value) do
    {script, value} = (references?(value) && reference(script, value)) || {script, value}

    %{script | stack: [value | stack]}
    |> debug("in stack: #{inspect(value)}")
  end

  def get_stack(script, retrieve \\ :value)

  def get_stack(%{stack: [first | next]} = script, retrieve) do
    first =
      case retrieve do
        :value ->
          (match?(%Reference{}, first) && Store.get_value(first, recursive: false)) || first

        :reference ->
          (match?(%Reference{}, first) && {Store.get_value(first, recursive: false), first}) || {first, first}
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

  def reference(script, value) do
    reference = Store.new_reference(value, script.id)

    script =
      script
      |> debug("create ref #{inspect(reference)} = #{inspect(value)}")

    {script, reference}
  end

  def references?(value) when is_atom(value), do: false
  def references?(%Method{}), do: false
  def references?(%SubMethod{}), do: false
  def references?(%Callable{}), do: false
  def references?(%Reference{}), do: false
  def references?(value) when is_number(value), do: false
  def references?(:none), do: false
  def references?(value) when is_boolean(value), do: false
  def references?(value) when is_binary(value), do: false
  def references?(%Format.String{}), do: false
  def references?(value) when is_tuple(value), do: false
  # Game modes structures should not be referenced
  def references?(_value), do: true

  def debug(%{debugger: %Debugger{} = debugger} = script, text) do
    debugger = Debugger.add(debugger, script.cursor - 1, text)

    %{script | debugger: debugger}
  end

  def debug(script, _text), do: script

  @doc """
  Set the parent script for this script.
  """
  @spec set_parent(t(), t()) :: t()
  def set_parent(script, parent_script) do
    %{script | parent: parent_script}
  end

  @doc """
  Set the next step to be executed when this script completes.

  Args:
  * script: the current script
  * module: the module containing the function to call
  * function: the function name (atom) to call
  * args: additional arguments to pass to the function
  """
  @spec set_step(t(), atom(), atom(), list()) :: t()
  def set_step(script, module, function, args \\ []) when is_atom(module) and is_atom(function) and is_list(args) do
    %{script | step: {module, function, args}}
  end

  @doc """
  Get the parent script, if any.
  """
  @spec get_parent(t()) :: t() | nil
  def get_parent(%{parent: parent}), do: parent

  @doc """
  Get the next step, if any.
  """
  @spec get_step(t()) :: {atom(), atom(), list()} | nil
  def get_step(%{step: step}), do: step

  @doc """
  Execute the next step if defined, passing the script status and structure.

  Args:
  * script: the completed script
  * status: :ok | :error
  """
  @spec execute_step(t(), :ok | :error) :: any()
  def execute_step(%{step: {module, function, args}} = script, status) do
    apply(module, function, [status, script | args])
  rescue
    error ->
      require Logger
      Logger.error("Failed to execute step #{inspect(module)}.#{function}: #{inspect(error)}")
      {:error, error}
  end

  def execute_step(_script, _status), do: :no_step
end
