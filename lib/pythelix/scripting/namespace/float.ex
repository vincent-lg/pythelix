defmodule Pythelix.Scripting.Namespace.Float do
  @moduledoc """
  Module defining the float object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

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
