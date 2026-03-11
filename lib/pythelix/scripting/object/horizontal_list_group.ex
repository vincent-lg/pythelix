defmodule Pythelix.Scripting.Object.HorizontalListGroup do
  @moduledoc """
  A group within a horizontal list display object.
  """

  defstruct title: "", entries: []

  @type t :: %__MODULE__{
          title: String.t(),
          entries: [String.t()]
        }
end
