defmodule Pythelix.Scripting.Namespace.Ellipsis do
  @moduledoc """
  Module defining the ellipsis object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defp repr(script, _self) do
    "..."
    |> then(& {script, &1})
  end
end
