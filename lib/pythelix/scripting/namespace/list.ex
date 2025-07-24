defmodule Pythelix.Scripting.Namespace.List do
  @moduledoc """
  Module defining the list object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    element = Store.get_value(namespace.element, recursive: false)
    {script, Enum.member?(list, element)}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet append(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    former = Store.get_value(namespace.self, recursive: false)
    Store.update_reference(namespace.self, List.insert_at(former, -1, namespace.value))

    {script, :none}
  end

  defp repr(script, self) do
    Store.get_value(self)
    |> Enum.map(fn
      :ellipsis -> "[...]"
      value -> Display.repr(script, value)
    end)
    |> Enum.join(", ")
    |> then(fn list -> {script, "[#{list}]"} end)
  end
end
