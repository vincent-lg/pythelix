defmodule Pythelix.Scripting.Interpreter.VM.Tuple do
  @moduledoc """
  Grouping of tuple operations.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Tuple

  def unpack(script, n) do
    {script, value} = Script.get_stack(script)

    elements =
      case value do
        %Tuple{elements: elems} -> {:ok, elems}
        list when is_list(list) -> {:ok, list}
        _ -> :error
      end

    case elements do
      {:ok, elems} when length(elems) == n ->
        Enum.reduce(Enum.reverse(elems), script, fn elem, script ->
          Script.put_stack(script, elem)
        end)

      {:ok, elems} ->
        got = length(elems)
        msg = "not enough values to unpack (expected #{n}, got #{got})"
        Script.raise(script, ValueError, msg)

      :error ->
        Script.raise(script, TypeError, "cannot unpack non-sequence")
    end
  end

  def new(script, len) do
    {script, values} =
      if len > 0 do
        Enum.reduce(1..len, {script, []}, fn _, {script, values} ->
          {script, value} = Script.get_stack(script)
          {script, [value | values]}
        end)
      else
        {script, []}
      end

    script
    |> Script.put_stack(%Tuple{elements: values})
  end
end
