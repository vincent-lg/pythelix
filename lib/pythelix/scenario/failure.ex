defmodule Pythelix.Scenario.Failure do
  @moduledoc """
  One expectation in a [scenario](`Pythelix.Scenario`) that didn't hold.

  A failure quotes the line, says what went wrong and — this is the part that
  matters — shows what the player actually saw. Knowing that Alice didn't see
  "a bundle of wheat" is half an answer; seeing that she saw "You can't carry
  any more" is the whole one.
  """

  defstruct [:line, :source, :message, :expected, received: []]

  @type t :: %__MODULE__{
          line: pos_integer(),
          source: binary(),
          message: binary(),
          expected: binary() | nil,
          received: [binary()]
        }

  @doc """
  Render a failure as the lines to print.
  """
  @spec format(t(), binary() | nil) :: binary()
  def format(%__MODULE__{} = failure, file \\ nil) do
    location = [file, failure.line] |> Enum.reject(&is_nil/1) |> Enum.join(":")

    [
      "  #{location}  #{failure.source}",
      "    #{failure.message}",
      received(failure.received)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # A room description is many lines long. Keep its shape rather than joining
  # it into one, but cap it: past a dozen lines it stops being evidence and
  # starts being a wall to scroll past.
  @max_lines 12

  defp received([]), do: "    (nothing was received)"

  defp received(messages) do
    lines =
      messages
      |> Enum.flat_map(&String.split(&1, ~r/\r?\n/))
      |> Enum.reject(&(String.trim(&1) == ""))

    shown = Enum.take(lines, @max_lines)
    hidden = length(lines) - length(shown)

    ["    received:"] ++
      Enum.map(shown, &"      | #{String.trim_trailing(&1)}") ++
      if hidden > 0,
        do: ["      | ... #{hidden} more #{(hidden == 1 && "line") || "lines"}"],
        else: []
  end
end
