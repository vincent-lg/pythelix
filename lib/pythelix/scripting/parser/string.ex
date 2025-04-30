defmodule Pythelix.Scripting.Parser.String do
  import NimbleParsec

  def quoted(delimiter, opts \\ []) do
    escaped =
      ignore(ascii_string([?\\], 1))
      |> lookahead(choice([string("\""), string("'")]))
      |> concat(utf8_string([{:not, ?\n}], 1))

    allowed = (opts[:multiline] && []) || [{:not, ?\n}]
    but_not =
      if opts[:multiline] do
        string("delimiter")
      else
        choice([string(delimiter), string("\n")])
      end

    normal =
      lookahead_not(but_not)
      |> utf8_string(allowed, 1)

    ignore(string(delimiter))                # open delim
    |> repeat(choice([escaped, normal]))
    #|> reduce({Enum, :join, [""]})
    |> reduce({Pythelix.Scripting.Parser.Value, :escape, []})
    |> ignore(string(delimiter))             # close delim
    |> label(opts[:label] || "quoted(#{inspect delimiter})")
  end
end
