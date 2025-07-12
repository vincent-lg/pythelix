defmodule Pythelix.Scripting.Object.Attribute do
  @moduledoc """
  A bound entity attribute in Pythello.
  """

  alias Pythelix.Entity
  alias Pythelix.Scripting.Object.Attribute

  @enforce_keys [:entity, :attribute]
  defstruct [:entity, :attribute]

  @type t :: %Attribute{entity: Entity.t(), attribute: String.t()}

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Attribute{entity: entity, attribute: name}, opts) do
      concat(["<ttribute(", Inspect.inspect(entity, opts), ".", name, ")>"])
    end
  end
end
