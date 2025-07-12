defmodule Pythelix.Scripting.Object.Reference do
  @moduledoc """
  A reference in Pythello.
  """

  alias Pythelix.Scripting.Object.Reference

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %Reference{value: String.t()}

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Reference{value: value}, opts) do
      concat(["<Reference(", Inspect.inspect(value, opts), ")>"])
    end
  end
end
