defmodule Pythelix.Scripting.Format.Spec do
  @moduledoc """
  Parse and apply Python-style format specifications.

  Supported syntax: `[[fill]align][0][width][.precision][type]`

  - `fill`: any single character used for padding
  - `align`: `<` (left), `>` (right), `^` (center)
  - `0`: zero-padding shorthand (implies fill=`0`, align=`>`)
  - `width`: minimum field width (integer)
  - `.precision`: decimal places for floats (integer after `.`)
  - `type`: `d` (integer), `f` (fixed-point float), `s` (string)
  """

  defstruct fill: nil, align: nil, zero_pad: false, width: nil, precision: nil, type: nil

  @type t() :: %__MODULE__{
          fill: String.t() | nil,
          align: String.t() | nil,
          zero_pad: boolean(),
          width: non_neg_integer() | nil,
          precision: non_neg_integer() | nil,
          type: String.t() | nil
        }

  @align_chars ~w(< > ^)

  @spec parse(nil | String.t()) :: {:ok, t() | nil} | {:error, term()}
  def parse(nil), do: {:ok, nil}
  def parse(""), do: {:ok, nil}

  def parse(spec) when is_binary(spec) do
    graphemes = String.graphemes(spec)

    with {:ok, fill, align, rest} <- parse_fill_align(graphemes),
         {:ok, zero_pad, rest} <- parse_zero(rest),
         {:ok, width, rest} <- parse_width(rest),
         {:ok, precision, rest} <- parse_precision(rest),
         {:ok, type} <- parse_type(rest) do
      {:ok,
       %__MODULE__{
         fill: fill,
         align: align,
         zero_pad: zero_pad,
         width: width,
         precision: precision,
         type: type
       }}
    end
  end

  defp parse_fill_align([fill, align | rest]) when align in @align_chars do
    {:ok, fill, align, rest}
  end

  defp parse_fill_align([align | rest]) when align in @align_chars do
    {:ok, nil, align, rest}
  end

  defp parse_fill_align(rest), do: {:ok, nil, nil, rest}

  defp parse_zero(["0" | rest]), do: {:ok, true, rest}
  defp parse_zero(rest), do: {:ok, false, rest}

  defp parse_width(graphemes) do
    {digits, rest} = Enum.split_while(graphemes, &digit?/1)
    width = if digits == [], do: nil, else: digits |> Enum.join() |> String.to_integer()
    {:ok, width, rest}
  end

  defp parse_precision(["." | rest]) do
    {digits, rest} = Enum.split_while(rest, &digit?/1)

    if digits == [] do
      {:error, {:invalid_format_spec, "missing precision after '.'"}}
    else
      {:ok, digits |> Enum.join() |> String.to_integer(), rest}
    end
  end

  defp parse_precision(rest), do: {:ok, nil, rest}

  defp parse_type([]), do: {:ok, nil}
  defp parse_type([type]) when type in ~w(d f s), do: {:ok, type}

  defp parse_type(other) do
    {:error, {:invalid_format_spec, "unexpected: #{Enum.join(other)}"}}
  end

  defp digit?(g), do: g >= "0" and g <= "9"

  @doc """
  Apply the format spec to a value, returning a formatted string.
  """
  @spec apply(term(), t()) :: String.t()
  def apply(value, %__MODULE__{} = spec) do
    formatted = format_value(value, spec)
    pad(formatted, spec)
  end

  # Integer with type "d"
  defp format_value(value, %{type: "d"}) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_value(value, %{type: "d"}) when is_float(value) do
    Integer.to_string(trunc(value))
  end

  # Float with type "f"
  defp format_value(value, %{type: "f", precision: p}) when is_integer(value) do
    :erlang.float_to_binary(value * 1.0, decimals: p || 6)
  end

  defp format_value(value, %{type: "f", precision: p}) when is_float(value) do
    :erlang.float_to_binary(value, decimals: p || 6)
  end

  # String type
  defp format_value(value, %{type: "s"}) when is_binary(value), do: value
  defp format_value(value, %{type: "s"}), do: to_string(value)

  # No type, with precision → treat as float
  defp format_value(value, %{type: nil, precision: p})
       when is_float(value) and not is_nil(p) do
    :erlang.float_to_binary(value, decimals: p)
  end

  defp format_value(value, %{type: nil, precision: p})
       when is_integer(value) and not is_nil(p) do
    :erlang.float_to_binary(value * 1.0, decimals: p)
  end

  # Default
  defp format_value(value, _spec) when is_binary(value), do: value
  defp format_value(value, _spec), do: to_string(value)

  defp pad(str, %{width: nil}), do: str

  defp pad(str, %{width: width} = spec) do
    len = String.length(str)

    if len >= width do
      str
    else
      fill = spec.fill || if(spec.zero_pad, do: "0", else: " ")
      align = spec.align || default_align(spec)
      pad_size = width - len

      case align do
        ">" -> String.duplicate(fill, pad_size) <> str
        "<" -> str <> String.duplicate(fill, pad_size)
        "^" ->
          left = div(pad_size, 2)
          right = pad_size - left
          String.duplicate(fill, left) <> str <> String.duplicate(fill, right)
      end
    end
  end

  defp default_align(%{zero_pad: true}), do: ">"
  defp default_align(%{type: t}) when t in ["d", "f"], do: ">"
  defp default_align(_), do: "<"
end
