defmodule Pythelix.Scripting.Interpreter.Debugger do
  @moduledoc """
  Debugger to follow script execution.

  The debugger is responsible for providing one or more messages
  per executed bytecode.
  """

  defstruct lines: []

  alias Pythelix.Scripting.Interpreter.Debugger

  @doc """
  Creates a new debugger.
  """
  def new do
    %Debugger{lines: []}
  end

  @doc """
  Add a new line of dbugging.
  """
  def add(%{lines: lines} = debugger, bytecode, text) do
    %{debugger | lines: [{bytecode, text} | lines]}
  end

  @doc """
  Returns a formatted string with the debugging information.
  """
  def format(%{debugger: debugger} = script) do
    {_, lines} =
      Enum.reduce(Enum.reverse(debugger.lines), {nil, []}, fn {index, text}, {last, lines} ->
        byte = Enum.at(script.bytecode, index)
        name = (byte && inspect(byte)) || "end"
        len_indent = String.length(to_string(index))
        indent = String.duplicate(" ", len_indent)

        text =
          if last == index do
            "#{indent} #{text}"
          else
            pad_indent = String.pad_leading(to_string(index), len_indent)
            "#{pad_indent} #{name}\n#{indent} #{text}"
          end

        {index, [text | lines]}
      end)

    Enum.join(Enum.reverse(lines), "\n")
  end
end
