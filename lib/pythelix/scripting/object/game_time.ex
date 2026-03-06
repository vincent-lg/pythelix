defmodule Pythelix.Scripting.Object.GameTime do
  @moduledoc """
  A game time object in Pythello, representing a snapshot of game time
  with computed unit values and properties for a specific calendar.
  """

  alias Pythelix.Scripting.Object.GameTime

  defstruct [:calendar, :epoch, units: %{}, properties: %{}]

  @type t :: %GameTime{
          calendar: any(),
          epoch: integer(),
          units: map(),
          properties: map()
        }

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%GameTime{units: units}, _opts) do
      parts =
        units
        |> Enum.sort()
        |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
        |> Enum.join(", ")

      concat(["<GameTime ", parts, ">"])
    end
  end
end
