defmodule Pythelix.Scripting.Namespace.Float do
  @moduledoc """
  Module defining the float object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet __bool__(script, namespace), [] do
    {script, namespace.self != 0.0}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defp repr(script, self) do
    to_string(self)
    |> then(& {script, &1})
  end
end
