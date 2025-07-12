defmodule Pythelix.Scripting.Namespace.NewSubEntity do
  @moduledoc """
  Module defining the NewSubEntity object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defp repr(script, {:sub_entity, self}) do
    {script, "<#{self.key}>"}
  end
end
