defmodule Pythelix.Scripting.Interpreter.AST do
  @moduledoc """
  A module to convert an Abstract-Syntax Tree (AST) into a script structure.
  """

  alias Pythelix.Scripting.Interpreter.{Script, AST.Core}
  alias Pythelix.Scripting.Store

  @doc """
  Convert an AST into a script structure with its bytecode.
  """
  @spec convert(list()) :: Script.t()
  def convert(ast, opts \\ []) do
    bytecode =
      ast
      |> Enum.reduce(:queue.new(), &process_ast/2)
      |> :queue.to_list()

    %Script{id: (opts[:id] || Store.new_script()), bytecode: bytecode}
  end

  defp process_ast(ast, code) do
    Core.read_ast(code, ast)
  end
end
