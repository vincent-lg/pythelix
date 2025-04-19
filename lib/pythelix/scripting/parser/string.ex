defmodule Pythelix.Scripting.Parser.String do
  def handle_single(<<?', _::binary>>, %{escape: false} = context, _, _), do: {:halt, context}

  def handle_single(<<?\\, _::binary>>, context, _, _),
    do: {:cont, Map.put(context, :escape, true)}

  def handle_single(_, context, _, _), do: {:cont, Map.put(context, :escape, false)}

  def handle_double(<<?", _::binary>>, %{escape: false} = context, _, _), do: {:halt, context}

  def handle_double(<<?\\, _::binary>>, context, _, _),
    do: {:cont, Map.put(context, :escape, true)}

  def handle_double(_, context, _, _), do: {:cont, Map.put(context, :escape, false)}

  def process(rest, string, context, _line, _offset) do
    string =
      string
      |> Enum.join("")
      |> escape_string("")

    {rest, [string], Map.delete(context, :escape)}
  end

  def escape_string(<<>>, acc), do: acc

  def escape_string(<<?\\, ?", rest::binary>>, acc) do
    escape_string(rest, acc <> <<?">>)
  end

  def escape_string(<<?\\, ?', rest::binary>>, acc) do
    escape_string(rest, acc <> <<?'>>)
  end

  def escape_string(<<?\\, ?n, rest::binary>>, acc) do
    escape_string(rest, acc <> "\n")
  end

  def escape_string(<<head::utf8, tail::binary>>, acc) do
    escape_string(tail, acc <> <<head::utf8>>)
  end
end
