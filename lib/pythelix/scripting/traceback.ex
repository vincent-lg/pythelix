defmodule Pythelix.Scripting.Traceback do
  @doc """
  Module defining a traceback.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  @enforce_keys [:exception, :message]
  defstruct [:exception, :message, chain: []]

  @typedoc "A link in the chain of exceptions"
  @type link() :: {Script.t(), String.t() | nil, String.t() | nil}

  @typedoc "A traceback"
  @type t() :: %{exception: atom(), message: String.t(), chain: [link()]}

  @doc """
  Raises an exception.

  The code associated with the exception will be automatically set by
  the interpreter. The script usually has to raise the exception
  without code.

  Args:

  * script (Script): the script.
  * exception (atom): the exception identifier.
  * message (string): the exception message.
  * code (string, optional): the code that raised this exception.
  """
  @spec raise(Script.t(), atom(), String.t() | nil, String.t() | nil) :: Script.t()
  def raise(script, exception, message, code \\ nil, owner \\ nil) do
    %Traceback{exception: exception, message: message, chain: [{script, code, owner}]}
  end

  @doc """
  Add an upper link to the chain of traceback.
  """
  @spec link(t(), Script.t(), binary() | nil, binary() | nil) :: t()
  def link(traceback, script, code \\ nil, owner \\ nil) do
    %{traceback | chain: [{script, code, owner} | traceback.chain]}
  end

  @doc """
  Build, starting from the bottomest script.
  """
  def build_from_bottom(traceback) do
    start = %Traceback{exception: traceback.exception, message: traceback.message}
    get_parents = fn script ->
      rec = fn
        parents, %Script{parent: %Script{} = parent} = script, fun -> [script | fun.(parents, parent, fun)]
        parents, script, _fun -> [script | parents]
      end

      rec.([], script, rec)
    end

    [{%Script{} = script, _, _} | _] = traceback.chain
    parents = get_parents.(script)

    Enum.reduce(parents, start, fn script, traceback ->
      script = %{script | error: nil, parent: nil}
      %{traceback | chain: [{script, script.code, script.name} | traceback.chain]}
    end)
  end

  @doc """
  Associate code and owner to the last link.

  Args:

  * traceback (Traceback): the traceback.
  * code (string): the code to be used.
  * owner (string): the owner of the code.
  """
  @spec associate(t(), String.t(), String.t()) :: t()
  def associate(%{chain: [{chain_script, _, _} | rest]} = traceback, code, owner) do
    %{traceback | chain: [{chain_script, code, owner} | rest]}
  end

  @doc """
  Return a list of tuples with three elements for each traceback chain.
  The tuple contains the script name, the line number that caused the error
  and the matching line in code. This is useful to browse the traceback
  without formatting it.
  """
  @spec introspect(t()) :: [{String.t(), integer(), String.t()}]
  def introspect(traceback) do
    traceback.chain
    |> Enum.reject(fn {_, code, owner} ->
      (code == nil) || (owner == nil)
    end)
    |> Enum.map(fn {script, _code, owner} = chain ->
      {owner, script.line, format_code(chain)}
    end)
  end

  @doc """
  Return a string representing the traceback.

  Args:

  * traceback (Traceback: the full traceback.
  """
  @spec format(t()) :: Sting.t()
  def format(traceback) do
    chain =
      traceback.chain
      |> Enum.reject(fn {_, code, owner} ->
        (code == nil) || (owner == nil)
      end)
      |> Enum.flat_map(fn chain ->
        ["  " <> format_call(chain), "    " <> format_code(chain)]
      end)
      |> Enum.join("\n")

    header = "Traceback most recent call last:"

    type = inspect(traceback.exception)
    message = traceback.message

    "#{header}\n#{chain}\n\n#{type}: #{message}"
  end

  defp format_call({script, _, nil}) do
    "Unknown, line #{script.line}"
  end

  defp format_call({script, _, owner}) do
    "#{owner}, line #{script.line}"
  end

  defp format_code({_script, nil, _}) do
    "Unknown code"
  end

  defp format_code({script, code, _}) do
    line_no = script.line
    line_at_fault = Enum.at(String.split(code, "\n"), line_no - 1, "unknown")

    "#{String.trim_leading(line_at_fault)}"
  end
end
