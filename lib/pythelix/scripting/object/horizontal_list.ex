defmodule Pythelix.Scripting.Object.HorizontalList do
  @moduledoc """
  A horizontal list display object for the Pythelix scripting language.

  Groups entries into named groups and formats them in columns.
  """

  alias Pythelix.Scripting.Object.HorizontalListGroup

  defstruct groups: [], indent: 2, columns: 3, col_width: 20

  @type t :: %__MODULE__{
          groups: [HorizontalListGroup.t()],
          indent: non_neg_integer(),
          columns: pos_integer(),
          col_width: pos_integer()
        }
end
