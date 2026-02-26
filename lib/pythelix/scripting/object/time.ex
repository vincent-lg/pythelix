defmodule Pythelix.Scripting.Object.Time do
  @moduledoc """
  A time literal in Pythello, representing hour:minute[:second].
  """

  alias Pythelix.Scripting.Object.Time

  @enforce_keys [:hour, :minute, :second]
  defstruct [:hour, :minute, :second]

  @type t :: %Time{hour: non_neg_integer(), minute: non_neg_integer(), second: non_neg_integer()}

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Time{hour: h, minute: m, second: 0}, _opts) do
      concat([
        "<Time ",
        String.pad_leading(to_string(h), 2, "0"),
        ":",
        String.pad_leading(to_string(m), 2, "0"),
        ">"
      ])
    end

    def inspect(%Time{hour: h, minute: m, second: s}, _opts) do
      concat([
        "<Time ",
        String.pad_leading(to_string(h), 2, "0"),
        ":",
        String.pad_leading(to_string(m), 2, "0"),
        ":",
        String.pad_leading(to_string(s), 2, "0"),
        ">"
      ])
    end
  end
end
