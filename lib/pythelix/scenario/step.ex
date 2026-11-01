defmodule Pythelix.Scenario.Step do
  @moduledoc """
  One line of a [scenario](`Pythelix.Scenario`), and how it is read.

  Each construct is matched by one anchored pattern. A line that matches none
  of them is an error naming what was expected, rather than being skipped:
  silently ignoring a line the author meant as an assertion would let a
  scenario pass without ever checking anything.
  """

  defstruct [:kind, :actor, :text, :count, :target, :line]

  @type kind :: :apply | :given | :place | :connect | :wait | :input | :sees | :not_sees

  @type t :: %__MODULE__{
          kind: kind(),
          # Who the step is about: a player name, or nothing for `:apply`
          # and `:place`.
          actor: binary() | nil,
          # The payload: a room key for `:given`, a prototype key for
          # `:place`, the duration as written for `:wait`, the input or
          # expected text for the rest.
          text: binary(),
          # `:place`: how many, and where they go. `:wait`: the duration in
          # milliseconds.
          count: pos_integer() | nil,
          target: binary() | nil,
          line: pos_integer()
        }

  @type error :: %{line: pos_integer(), source: binary(), message: binary()}

  # A name is a bare word, so that `Alice sees "..."` can never be confused
  # with text that happens to contain the word "sees".
  @name "[A-Za-z][A-Za-z0-9_]*"

  @patterns [
    {:apply, ~r/^apply\s+(?<text>\S.*?)\s*$/},
    # Things before players: a prototype key can never be a bare name, so the
    # two `given` forms cannot be confused.
    {:place,
     ~r/^given\s+(?:(?<count>\d+)\s+)?(?<text>!.+?!)\s+in\s+(?<target>!.+!|#{@name})\s*$/},
    {:given, ~r/^given\s+(?<actor>#{@name})\s+in\s+(?<text>!.+!)\s*$/},
    {:connect, ~r/^connect\s+(?<actor>#{@name})\s*$/},
    {:wait, ~r/^wait\s+(?<text>\S.*?)\s*$/},
    {:not_sees, ~r/^(?<actor>#{@name})\s+does\s+not\s+see\s+"(?<text>.*)"\s*$/},
    {:sees, ~r/^(?<actor>#{@name})\s+sees\s+"(?<text>.*)"\s*$/},
    {:input, ~r/^(?<actor>#{@name})>\s?(?<text>.*?)\s*$/}
  ]

  @doc """
  Render a step back into the line an author would have written.

  Used when reporting a failure, so the report quotes the scenario rather than
  an internal shape.
  """
  @spec render(t()) :: binary()
  def render(%__MODULE__{kind: :apply, text: text}), do: "apply #{text}"
  def render(%__MODULE__{kind: :given, actor: a, text: t}), do: "given #{a} in #{t}"
  def render(%__MODULE__{kind: :connect, actor: a}), do: "connect #{a}"
  def render(%__MODULE__{kind: :wait, text: t}), do: "wait #{t}"

  def render(%__MODULE__{kind: :place, count: nil, text: t, target: to}),
    do: "given #{t} in #{to}"

  def render(%__MODULE__{kind: :place, count: n, text: t, target: to}),
    do: "given #{n} #{t} in #{to}"

  def render(%__MODULE__{kind: :input, actor: a, text: t}), do: "#{a}> #{t}"
  def render(%__MODULE__{kind: :sees, actor: a, text: t}), do: ~s|#{a} sees "#{t}"|
  def render(%__MODULE__{kind: :not_sees, actor: a, text: t}), do: ~s|#{a} does not see "#{t}"|

  @doc """
  Read one line.

  Returns `:skip` for blanks and comments, `{:ok, step}` for a construct, and
  `{:error, error}` for anything else.
  """
  @spec parse(binary(), pos_integer()) :: :skip | {:ok, t()} | {:error, error()}
  def parse(line, number) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" -> :skip
      String.starts_with?(trimmed, "#") -> :skip
      true -> match(trimmed, line, number)
    end
  end

  defp match(trimmed, line, number) do
    Enum.find_value(@patterns, fn {kind, regex} ->
      case Regex.named_captures(regex, trimmed) do
        nil ->
          nil

        captures ->
          build(kind, captures, line, number)
      end
    end) || {:error, unknown(trimmed, line, number)}
  end

  # A wait is only a step once its duration reads: `wait 3h` is one, `wait
  # for the bread` is a line the author meant as something else.
  defp build(:wait, %{"text" => text}, line, number) do
    case duration(text) do
      {:ok, ms} ->
        {:ok, %__MODULE__{kind: :wait, text: text, count: ms, line: number}}

      :error ->
        message =
          "expected a duration, as in `wait 30s`, `wait 2m`, `wait 3h`, " <>
            "`wait 1d` or `wait 1h30m`"

        {:error, %{line: number, source: line, message: message}}
    end
  end

  defp build(kind, captures, _line, number) do
    {:ok,
     %__MODULE__{
       kind: kind,
       actor: blank_to_nil(captures["actor"]),
       text: captures["text"],
       count: count(captures["count"]),
       target: blank_to_nil(captures["target"]),
       line: number
     }}
  end

  @units %{"s" => 1_000, "m" => 60_000, "h" => 3_600_000, "d" => 86_400_000}

  @doc """
  Read a duration such as `30s`, `2m`, `3h`, `1d` or `1h30m` into milliseconds.

  A bare number is seconds. Parts may be joined with or without spaces.
  """
  @spec duration(binary()) :: {:ok, non_neg_integer()} | :error
  def duration(text) do
    parts = Regex.scan(~r/(\d+)\s*([smhd]?)/, String.downcase(text))

    cond do
      parts == [] ->
        :error

      Regex.replace(~r/(\d+)\s*([smhd]?)\s*/, String.downcase(text), "") != "" ->
        :error

      true ->
        {:ok,
         Enum.reduce(parts, 0, fn [_, number, unit], total ->
           total + String.to_integer(number) * Map.get(@units, unit, 1_000)
         end)}
    end
  end

  # Say what was expected rather than only that the line is wrong: the mistake
  # is nearly always a missing pair of quotes or a renamed keyword.
  defp unknown(trimmed, line, number) do
    message =
      cond do
        String.starts_with?(trimmed, "given") ->
          "expected `given Alice in !room/somewhere!`, " <>
            "or `given 30 !gold/coin! in !room/somewhere!`"

        String.starts_with?(trimmed, "connect") ->
          "expected: connect Alice"

        String.starts_with?(trimmed, "wait") ->
          "expected a duration, as in: wait 3h"

        String.starts_with?(trimmed, "apply") ->
          "expected: apply worldlets/somewhere"

        Regex.match?(~r/^#{@name}\s+(?:does\s+not\s+)?sees?\b/, trimmed) ->
          ~s|expected the text in double quotes, as in: Alice sees "some text"|

        Regex.match?(~r/^#{@name}\s/, trimmed) ->
          ~s|expected `Name> input`, `Name sees "text"` or `Name does not see "text"`|

        true ->
          "expected `apply`, `given`, `connect`, `wait`, `Name>`, `Name sees` " <>
            "or `Name does not see`"
      end

    %{line: number, source: line, message: message}
  end

  defp blank_to_nil(value) when value in ["", nil], do: nil
  defp blank_to_nil(value), do: value

  defp count(value) when value in ["", nil], do: nil
  defp count(value), do: String.to_integer(value)
end
