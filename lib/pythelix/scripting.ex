defmodule Pythelix.Scripting do
  @moduledoc """
  Scripting module, a higher-level module to manipulate scripts.

  This module groups the parser and interpreter together.
  It is designed to parse a string, generate AST, bytecode and execute
  the script.
  """

  alias Pythelix.Scripting.{Interpreter, Parser, Traceback}

  @doc """
  Executes the given instructions and returns a script structure.

  This function will parse the given string and turn it into an
  Abstract Syntax Tree (AST), turn the AST into bytecode and
  execute this bytecode, returning the executed script.
  """
  @spec run(binary()) :: {:ok, Interpreter.Script.t()} | {:error, term()}
  def run(code, opts \\ []) do
    debug = Keyword.get(opts, :debug, false)
    call = Keyword.get(opts, :call, true)
    show_ast = Keyword.get(opts, :show_ast, false)
    line = Keyword.get(opts, :line, 1)
    former_script = Keyword.get(opts, :script)

    ast =
      case Parser.exec(code) do
        {:ok, ast} -> ast
        {:error, _} -> :error
    end

    if show_ast, do: IO.inspect(ast, label: "ast")

    script =
      if ast == :error do
        %Interpreter.Script{bytecode: []}
        |> then(fn script ->
          message = "invalid syntax"
          traceback = %Traceback{exception: SyntaxError, message: message, chain: [{script, nil, nil}]}
          traceback = Traceback.associate(traceback, code, "<strdin>")
          %{script | error: traceback}
        end)
      else
        [ast]
        |> Interpreter.AST.convert()
      end

    script =
      case former_script do
        nil -> script
        new_script -> %{new_script | bytecode: script.bytecode}
      end

    script =
      if debug do
        %{script | debugger: Interpreter.Debugger.new()}
      else
        script
      end

    if opts[:line] do
      bytecode =
        script.bytecode
        |> Enum.map(fn
          {:line, old_line} -> {:line, old_line + line}
          other -> other
        end)

        %{script | bytecode: bytecode, line: line}
      else
        script
      end
    |> then(fn
      %Interpreter.Script{error: nil} = script ->
        if call do
          Interpreter.Script.execute(script)
        else
          script
        end

      script ->
        script
    end)
  end

  @doc """
  Evaluates the code and return the result.

  Args:

  * code (string) the cod to be evaluated.

  This can be a multiline expression. For the scripting parser,
  this is considered something "raw", meaning the result would simply be
  popped from the stack. However, this time we pull the last "raw" value
  and return it. So that:

      (iex) Pythelix.Scripting.eval("1 + 4")
      {:ok, 5}
      (iex) Pythelix.Scripting.eval("value = 2 * 54")
      {:ok, nil}
      (iex) Pythelix.Scripting.eval("i = 5\ni * 3")
      {:ok, 15}

  """
  @spec eval(String.t(), Keyword.t()) :: {:ok, any} | {:error, String.t()}
  def eval(code, opts \\ []) do
    run(code, opts)
    |> then(fn
      %Interpreter.Script{error: %Traceback{} = traceback} ->
        {:error, traceback}

      script ->
        {:ok, Interpreter.Script.get_value(script, script.last_raw)}
    end)
  end
end
