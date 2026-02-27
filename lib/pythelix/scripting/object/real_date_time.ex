defmodule Pythelix.Scripting.Object.RealDateTime do
  @moduledoc """
  A real date-time object in Pythello, wrapping an Elixir DateTime.
  """

  alias Pythelix.Scripting.Object.RealDateTime

  @enforce_keys [:datetime]
  defstruct [:datetime]

  @type t :: %RealDateTime{datetime: DateTime.t()}

  @doc """
  Add seconds to a RealDateTime, preserving the local offset.
  Roundtrips through Unix time so DST is re-evaluated.
  """
  def add_seconds(%RealDateTime{datetime: dt}, seconds) do
    unix = DateTime.to_unix(dt) + seconds
    %RealDateTime{datetime: DateTime.from_unix!(unix) |> to_local()}
  end

  @doc """
  Convert a UTC DateTime to local wall-clock time using the OS offset.
  """
  def to_local(%DateTime{} = utc_dt) do
    {{ly, lm, ld}, {lh, lmin, ls}} = :calendar.local_time()
    {{uy, um, ud}, {uh, umin, us}} = :calendar.universal_time()

    local_secs = :calendar.datetime_to_gregorian_seconds({{ly, lm, ld}, {lh, lmin, ls}})
    utc_secs   = :calendar.datetime_to_gregorian_seconds({{uy, um, ud}, {uh, umin, us}})
    offset_seconds = local_secs - utc_secs

    sign = if offset_seconds >= 0, do: "+", else: "-"
    total = abs(offset_seconds)
    h = String.pad_leading(to_string(div(total, 3600)), 2, "0")
    m = String.pad_leading(to_string(div(rem(total, 3600), 60)), 2, "0")
    offset_string = "#{sign}#{h}:#{m}"

    utc_dt
    |> DateTime.add(offset_seconds, :second)
    |> Map.put(:utc_offset, offset_seconds)
    |> Map.put(:std_offset, 0)
    |> Map.put(:zone_abbr, offset_string)
    |> Map.put(:time_zone, offset_string)
  end

  defimpl Inspect do
    import Inspect.Algebra
    alias Pythelix.Scripting.Namespace.RealDateTime, as: NS

    def inspect(%RealDateTime{datetime: dt}, _opts) do
      concat(["<RealDateTime ", NS.format_dt(dt), ">"])
    end
  end
end
