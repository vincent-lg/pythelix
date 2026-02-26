defmodule Pythelix.Scripting.Object.Duration do
  @moduledoc """
  A duration literal in Pythello, representing a combination of
  seconds, minutes, hours, days, months, and years.
  """

  alias Pythelix.Scripting.Object.Duration

  defstruct seconds: 0, minutes: 0, hours: 0, days: 0, months: 0, years: 0

  @type t :: %Duration{
          seconds: non_neg_integer(),
          minutes: non_neg_integer(),
          hours: non_neg_integer(),
          days: non_neg_integer(),
          months: non_neg_integer(),
          years: non_neg_integer()
        }

  def total_seconds(%Duration{} = d) do
    d.seconds + d.minutes * 60 + d.hours * 3600 + d.days * 86400
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Duration{} = d, _opts) do
      parts =
        [
          {d.years, "y"},
          {d.months, "o"},
          {d.days, "d"},
          {d.hours, "h"},
          {d.minutes, "m"},
          {d.seconds, "s"}
        ]
        |> Enum.reject(fn {v, _} -> v == 0 end)
        |> Enum.map(fn {v, u} -> "#{v}#{u}" end)
        |> Enum.join()

      parts = if parts == "", do: "0s", else: parts

      concat(["<Duration ", parts, ">"])
    end
  end
end
