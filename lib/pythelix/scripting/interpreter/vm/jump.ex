defmodule Pythelix.Scripting.Interpreter.VM.Jump do
  @moduledoc """
  Grouping of jump operations.
  """

  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Interpreter.Script

  def iffalse(script, line) do
    {script, value} = Script.get_stack(script)

    if Display.to_bool(script, value) do
      script
      |> Script.debug("is true")
    else
      script
      |> Script.put_stack(value)
      |> Script.debug("is false so jump")
      |> Script.jump(line)
    end
  end

  def iftrue(script, line) do
    {script, value} = Script.get_stack(script)

    if Display.to_bool(script, value) do
      script
      |> Script.put_stack(value)
      |> Script.debug("is true so jump")
      |> Script.jump(line)
    else
      script
      |> Script.debug("is false")
    end
  end

  def popiffalse(script, line) do
    {script, value} = Script.get_stack(script)

    if Display.to_bool(script, value) do
      script
      |> Script.debug("is true")
    else
      script
      |> Script.debug("is false so jump")
      |> Script.jump(line)
    end
  end

  def popiftrue(script, line) do
    {script, value} = Script.get_stack(script)

    if Display.to_bool(script, value) do
      script
      |> Script.debug("is true so jump")
      |> Script.jump(line)
    else
      script
      |> Script.debug("is false")
    end
  end

  def goto(script, line) do
    script
    |> Script.jump(line)
  end
end
