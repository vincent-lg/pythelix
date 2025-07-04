defmodule Pythelix.Scripting.Namespace.List do
  @moduledoc """
  Module defining the list object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet append(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    former = Script.get_value(script, namespace.self, recursive: false)

    script =
      script
      |> Script.update_reference(namespace.self, List.insert_at(former, -1, namespace.value))

    {script, :none}
  end

  defp repr(script, self) do
    Script.get_value(script, self)
    |> Enum.map(fn
      :ellipsis -> "[...]"
      value -> Display.repr(script, value)
    end)
    |> Enum.join(", ")
    |> then(fn set -> {script, "[#{set}]"} end)
  end
end
