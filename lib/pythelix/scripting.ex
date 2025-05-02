defmodule Pythelix.Scripting do
  @moduledoc """
  Scripting module, a higher-level module to manipulate scripts.

  This module groups the parser and interpreter together.
  It is designed to parse a string, generate AST, bytecode and execute
  the script.
  """

  alias Pythelix.Scripting.{Interpreter, Parser}

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

    {:ok, ast} = Parser.exec(code)

    if show_ast, do: IO.inspect(ast, label: "ast")

    script =
      [ast]
      |> Interpreter.AST.convert()

    script =
      if debug do
        %{script | debugger: Interpreter.Debugger.new()}
      else
        script
      end

    script = %{script | line: line}

    script =
      if opts[:repl] do
        bytecode = script.bytecode

        bytecode =
          if List.last(bytecode) == :pop do
            {_, bytecode} = List.pop_at(bytecode, -1)

            bytecode
          else
            bytecode
          end

        %{script | bytecode: bytecode}
      else
        script
      end

    script =
      if opts[:line] do
        bytecode =
          script.bytecode
          |> Enum.map(fn
            {:line, old_line} -> {:line, old_line + line}
            other -> other
          end)

        %{script | bytecode: bytecode}
      else
        script
      end

    if call do
      Interpreter.Script.execute(script)
    else
      script
    end
  end
end
