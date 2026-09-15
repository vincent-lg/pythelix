defmodule Pythelix.Scripting.Diagnostic do
  @moduledoc """
  Explain why a piece of Pythello doesn't parse.

  The parser itself only reports how far it got, which answers "where" but
  never "why". This module wraps it to produce something a builder can act on:
  the position, a message naming the actual problem, and — where we recognise
  the mistake — a hint stating the Pythello rule and a documentation page.

  Most people meeting Pythello read it as Python, and so do the assistants they
  ask for help. The recurring mistakes are therefore predictable: a block left
  for indentation to close, a comprehension, a lambda. Those are checked by
  name, before the generic parser error, because "lambdas are not supported;
  give the function a name with `def`" teaches the rule, while "could not
  parse" leaves the reader to guess.
  """

  alias Pythelix.Scripting.Parser.Statement
  alias Pythelix.Scripting.REPL

  defstruct [:file, :context, :line, :column, :message, :hint, :doc, :source]

  @type t :: %__MODULE__{
          file: binary() | nil,
          context: binary() | nil,
          line: pos_integer(),
          column: pos_integer() | nil,
          message: binary(),
          hint: binary() | nil,
          doc: binary() | nil,
          source: binary() | nil
        }

  # Python constructs Pythello doesn't have. Each entry carries what to write
  # instead, since being told a habit doesn't carry over is only half an answer.
  @pythonisms [
    {~r/\bend(?:for|while)\b/, "`endfor`/`endwhile` are not Pythello keywords",
     "`for` and `while` loops both close with `done`.", "scripting.md#loops"},
    {~r/\bendfunction\b|\benddef\b/, "methods are not closed with a keyword",
     "A method runs until the next `def` or the next `!entity!` header.", "methods.md"},
    {~r/\blambda\b/, "lambdas are not supported",
     "Give the function a name with `def`, or write the expression out in full.",
     "scripting.md#collections"},
    {~r/\[[^\[\]\n]*\bfor\b[^\[\]\n]*\bin\b/, "list comprehensions are not supported",
     "Build the list with a `for` loop and `append`, closing the loop with `done`.",
     "scripting.md#loops"},
    {~r/\{[^{}\n]*\bfor\b[^{}\n]*\bin\b/, "dict and set comprehensions are not supported",
     "Build the collection with a `for` loop, closing it with `done`.", "scripting.md#loops"},
    {~r/\(\s*[^()\n]*\bfor\b[^()\n]*\bin\b[^()\n]*\)/, "generator expressions are not supported",
     "Build the value with a `for` loop, closing it with `done`.", "scripting.md#loops"},
    {~r/\bexcept\b[^:\n]*\bas\b/, "an exception cannot be captured in a variable",
     "Write `except ValueError:` without `as`.", "scripting.md#tryexcept"},
    {~r/^\s*(?:import|from)\s+\w/m, "Pythello has no `import`",
     "Namespaces such as `random` and `realtime` are always available.", "scripting.md"},
    {~r/^\s*class\s+\w/m, "Pythello has no classes",
     "Use an entity and give it a `parent` to inherit attributes and methods.", "entities.md"},
    {~r/^\s*@\w/m, "decorators are not supported", nil, "methods.md"},
    {~r/^\s*with\s+.+\bas\b.*:/m, "`with` blocks are not supported", nil, "scripting.md"},
    {~r/:=/, "the walrus operator `:=` is not supported",
     "Assign on its own line first, then test the variable.", "scripting.md"}
  ]

  @doc """
  Check a piece of Pythello and return what's wrong with it.

  Returns an empty list when the code parses. Otherwise it returns a single
  diagnostic: parsing stops at the first problem, and the errors reported after
  one are usually its echoes rather than separate mistakes.

  Options:

    * `:file` — the file to name in the report;
    * `:context` — where this code sits, e.g. `"method run of !command/roll!"`;
    * `:line` — the line `code` starts on in that file (defaults to 1), so that
      positions are reported against the file rather than the snippet.
  """
  @spec check(binary(), keyword()) :: [t()]
  def check(code, opts \\ []) do
    base = Keyword.get(opts, :line, 1)

    found =
      cond do
        found = scan_pythonisms(code, base) -> found
        found = scan_blocks(code, base) -> found
        found = scan_parser(code, base) -> found
        true -> nil
      end

    case found do
      nil -> []
      found -> [build(found, code, opts, base)]
    end
  end

  @doc """
  Render a diagnostic as the lines to print in a terminal.
  """
  @spec format(t()) :: binary()
  def format(%__MODULE__{} = diagnostic) do
    location =
      [diagnostic.file, diagnostic.line, diagnostic.column]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(":")

    header =
      case diagnostic.context do
        nil -> location
        context -> "#{location}  in #{context}"
      end

    [
      header,
      "  #{diagnostic.message}",
      source_lines(diagnostic),
      diagnostic.hint && "  #{diagnostic.hint}",
      diagnostic.doc && "  → docs/#{diagnostic.doc}"
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  @doc """
  Render a diagnostic as a plain map, for `--json` output.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = diagnostic), do: Map.from_struct(diagnostic)

  # Scanning

  defp scan_pythonisms(code, base) do
    # Room descriptions are prose, and prose contains "from", "class" and "for
    # ... in" as ordinary English. Match against the code with every string and
    # comment blanked out, so only real syntax is considered.
    masked = mask_literals(code)

    Enum.find_value(@pythonisms, fn {regex, message, hint, doc} ->
      case Regex.run(regex, masked, return: :index) do
        [{offset, _length} | _] ->
          {line, column} = position_at(code, offset, base)
          %{line: line, column: column, message: message, hint: hint, doc: doc}

        nil ->
          nil
      end
    end)
  end

  defp scan_blocks(code, base) do
    case REPL.diagnose(code, line: base) do
      :complete ->
        nil

      {_status, detail} ->
        %{
          line: detail.line,
          column: nil,
          message: detail.message,
          hint: detail[:hint],
          doc: doc_for(detail)
        }
    end
  end

  defp scan_parser(code, base) do
    case Statement.exec(code) do
      {:ok, _ast, "", _, _, _} ->
        nil

      {:ok, _ast, rest, _, _, _} ->
        stalled(code, rest, base)

      {:error, _reason, rest, _, _, _} ->
        stalled(code, rest, base)
    end
  end

  # The parser consumes as much as it understands, so whatever is left begins
  # exactly where it gave up.
  defp stalled(code, rest, base) do
    consumed = byte_size(code) - byte_size(rest)
    {line, column} = position_at(code, consumed, base)

    snippet =
      rest
      |> String.split("\n", parts: 2)
      |> List.first()
      |> String.trim()

    message =
      case snippet do
        "" -> "unexpected end of input"
        snippet -> "cannot parse `#{ellipsis(snippet)}` from here"
      end

    %{line: line, column: column, message: message, hint: unbalanced_try(code), doc: nil}
  end

  # `try` isn't tracked as a block by the REPL scanner, so a missing `endtry`
  # only surfaces as a parser stall. Suggest it when the counts disagree — this
  # runs only once parsing has already failed, so a false positive costs a hint,
  # never a spurious error.
  defp unbalanced_try(code) do
    opens = length(Regex.scan(~r/^\s*try\s*:/m, code))
    closes = length(Regex.scan(~r/\bendtry\b/, code))

    if opens > closes do
      "A `try` block is not closed: Pythello ends it with `endtry`."
    end
  end

  # Building

  defp build(found, code, opts, base) do
    %__MODULE__{
      file: Keyword.get(opts, :file),
      context: Keyword.get(opts, :context),
      line: found.line,
      column: found[:column],
      message: found.message,
      hint: found[:hint],
      doc: found[:doc],
      source: code |> String.split("\n") |> Enum.at(found.line - base)
    }
  end

  defp source_lines(%__MODULE__{source: nil}), do: nil

  defp source_lines(%__MODULE__{source: source, column: column}) do
    line = "      #{source}"

    case column do
      nil -> line
      column -> [line, "      " <> String.duplicate(" ", max(column - 1, 0)) <> "^"]
    end
  end

  # Replace the contents of every string and comment with spaces, keeping each
  # byte and every newline in place so that an offset into the result is also an
  # offset into the original code.
  defp mask_literals(code), do: mask(code, :normal, [])

  defp mask(<<>>, _state, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp mask(<<q, q, q, rest::binary>>, :normal, acc) when q in [?", ?'],
    do: mask(rest, {:multi, q}, ["   " | acc])

  defp mask(<<q, q, q, rest::binary>>, {:multi, q}, acc),
    do: mask(rest, :normal, ["   " | acc])

  defp mask(<<?\\, c, rest::binary>>, {kind, q}, acc),
    do: mask(rest, {kind, q}, [<<?\s, blank(c)>> | acc])

  defp mask(<<q, rest::binary>>, :normal, acc) when q in [?", ?'],
    do: mask(rest, {:single, q}, [?\s | acc])

  defp mask(<<q, rest::binary>>, {:single, q}, acc), do: mask(rest, :normal, [?\s | acc])

  # A single-quoted string can't span lines; if one is left open, recover at the
  # newline rather than blanking the rest of the file.
  defp mask(<<?\n, rest::binary>>, {:single, _q}, acc), do: mask(rest, :normal, [?\n | acc])

  defp mask(<<?#, rest::binary>>, :normal, acc), do: mask(rest, :comment, [?\s | acc])
  defp mask(<<?\n, rest::binary>>, :comment, acc), do: mask(rest, :normal, [?\n | acc])

  defp mask(<<c, rest::binary>>, :normal, acc), do: mask(rest, :normal, [c | acc])
  defp mask(<<c, rest::binary>>, state, acc), do: mask(rest, state, [blank(c) | acc])

  defp blank(?\n), do: ?\n
  defp blank(_byte), do: ?\s

  # Byte offset to {line, column}, the line counted from `base` and the column
  # from 1.
  defp position_at(code, offset, base) do
    lines =
      code
      |> binary_part(0, offset)
      |> String.split("\n")

    {length(lines) + base - 1, String.length(List.last(lines)) + 1}
  end

  defp ellipsis(text) when byte_size(text) > 40, do: String.slice(text, 0, 37) <> "..."
  defp ellipsis(text), do: text

  defp doc_for(%{symbol: symbol}) when symbol in [:if], do: "scripting.md#conditions"
  defp doc_for(%{symbol: symbol}) when symbol in [:for, :while], do: "scripting.md#loops"
  defp doc_for(_detail), do: nil
end
