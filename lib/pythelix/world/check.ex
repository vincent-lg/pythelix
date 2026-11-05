defmodule Pythelix.World.Check do
  @moduledoc """
  Check worldlets without applying them.

  This parses the same files `Pythelix.World.apply/1` would, but stops before
  touching the cache or the database: nothing is created, updated or saved, and
  no server needs to be running. It answers one question — would this parse? —
  which is the question a builder has while still editing the file.

  Every attribute value and every method body is handed to
  `Pythelix.Scripting.Diagnostic`, so a problem is reported against its line in
  the worldlet, with the Pythello rule it breaks.
  """

  alias Pythelix.Scripting.Diagnostic
  alias Pythelix.World.File, as: WorldletFile
  alias Pythelix.World.Sources

  defstruct files: [], entities: 0, diagnostics: [], notices: []

  @type t :: %__MODULE__{
          files: [binary()],
          entities: non_neg_integer(),
          diagnostics: [Diagnostic.t()],
          notices: [binary()]
        }

  @doc """
  Check a worldlet file, a directory of worldlets, or `:all`.

  Returns a result holding the files that were read, how many entities they
  define and every diagnostic found. An empty `:diagnostics` means the worldlets
  parse. `:notices` are worth showing even then: a file that wasn't UTF-8 and
  was read with the fallback encoding, for instance.
  """
  @spec run(Sources.source()) :: {:ok, t()} | :nofile
  def run(source) do
    source = if is_binary(source), do: Pythelix.Paths.resolve(source), else: source

    case Sources.files(source) do
      {:ok, [_ | _] = files} -> {:ok, Enum.reduce(files, %__MODULE__{}, &check_file/2)}
      _nothing -> :nofile
    end
  end

  @doc """
  Explain why applying `path` failed, in Pythello terms.

  `Pythelix.World.apply/1` reports the first thing that went wrong the way
  Elixir saw it — a match error, or a method that wouldn't compile, with a
  stacktrace. Running the checker over the same path turns that into the
  diagnostics a builder can act on, and finds the other problems in the file
  at the same time.

  Returns `nil` when the failure isn't something the checker can explain (a
  cyclic parent, a database error), leaving the original message to stand.
  """
  @spec explain(Sources.source()) :: binary() | nil
  def explain(path) do
    case run(path) do
      {:ok, %{diagnostics: [_ | _] = diagnostics}} ->
        diagnostics
        |> Enum.map(&Diagnostic.format/1)
        |> Enum.join("\n\n")

      _ ->
        nil
    end
  rescue
    # Explaining a failure must never itself fail: the original error is the
    # one worth reporting.
    _error -> nil
  end

  defp check_file(path, result) do
    result = %{result | files: result.files ++ [path]}

    case WorldletFile.parse_file(path) do
      {:ok, entities, notices} ->
        diagnostics = Enum.flat_map(entities, &check_entity(&1, path))

        %{
          result
          | entities: result.entities + length(entities),
            diagnostics: result.diagnostics ++ diagnostics,
            notices: result.notices ++ notices
        }

      {:error, reason} ->
        %{result | diagnostics: result.diagnostics ++ recover(path, reason)}
    end
  end

  # When the file doesn't parse, the reported position is often not the real
  # mistake. A method with an unclosed block keeps swallowing lines — the next
  # entity header included — so the parser only gives up much later, in what
  # looks like a different entity.
  #
  # So re-read the file the blunt way, cutting it at every `!key!` and `def`
  # line, and check each method body on its own. Blocks can't leak from one to
  # the next, which puts each problem back where it was written, and reports
  # all of them rather than only the first.
  defp recover(path, reason) do
    path
    |> read_lines()
    |> chunks()
    |> Enum.flat_map(fn {kind, key, name, line, body} ->
      Diagnostic.check(Enum.join(body, "\n"),
        file: path,
        context: "#{kind} #{name} of !#{key}!",
        line: line
      )
    end)
    |> case do
      [] -> [structural(path, reason)]
      diagnostics -> diagnostics
    end
  end

  defp read_lines(path) do
    path
    |> Pythelix.Encoding.read_file!()
    |> String.split("\n")
    |> Enum.with_index(1)
  end

  # Cut the file into {kind, entity key, name, first line, body} without
  # interpreting anything, so that a broken block stops at the next header
  # instead of swallowing it.
  defp chunks(lines) do
    {chunks, _key, current} = Enum.reduce(lines, {[], nil, nil}, &scan_line/2)

    chunks |> close(current) |> Enum.reverse()
  end

  defp scan_line({line, number}, {chunks, key, current}) do
    case classify(line, key, current) do
      {:entity, new_key} ->
        {close(chunks, current), new_key, nil}

      {:method, name} ->
        # A method body starts on the line after the `def`.
        {close(chunks, current), key, {:method, key, name, number + 1, []}}

      {:attribute, name, value} ->
        {close(chunks, current), key, {:attribute, key, name, number, [value]}}

      :content when current != nil ->
        {chunks, key, append(current, line)}

      :content ->
        {chunks, key, current}
    end
  end

  defp classify(line, key, current) do
    cond do
      new_key = capture(~r/^!(.*?)!\s*$/, line) -> {:entity, new_key}
      key == nil -> :content
      name = capture(~r/^def\s+([A-Za-z_][A-Za-z0-9_]*)\s*[(:]/, line) -> {:method, name}
      true -> attribute_or_content(line, current)
    end
  end

  # Attributes sit at the start of a line, and only outside a method: once a
  # method has begun, `=` lines are part of its body.
  defp attribute_or_content(_line, {:method, _key, _name, _start, _body}), do: :content

  defp attribute_or_content(line, _current) do
    case Regex.run(~r/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/, line) do
      [_, name, value] -> {:attribute, name, value}
      nil -> :content
    end
  end

  defp append({kind, key, name, line, body}, added), do: {kind, key, name, line, [added | body]}

  defp close(chunks, {kind, key, name, line, body}),
    do: [{kind, key, name, line, Enum.reverse(body)} | chunks]

  defp close(chunks, _current), do: chunks

  defp capture(regex, line) do
    case Regex.run(regex, line) do
      nil -> nil
      [_, capture | _] -> capture
    end
  end

  defp check_entity(entity, path) do
    check_attributes(entity, path) ++ check_methods(entity, path)
  end

  defp check_attributes(entity, path) do
    Enum.flat_map(entity.attributes, fn {name, value} ->
      Diagnostic.check(to_code(value),
        file: path,
        context: "attribute #{name} of !#{entity.key}!",
        line: Map.get(entity.attribute_lines, name, entity.line)
      )
    end)
  end

  defp check_methods(entity, path) do
    Enum.flat_map(entity.methods, fn {name, {_args, body}} ->
      # The body starts on the line after the `def`.
      line = Map.get(entity.method_lines, name, entity.line) + 1

      Diagnostic.check(body,
        file: path,
        context: "method #{name} of !#{entity.key}!",
        line: line
      )
    end)
  end

  # A multiline attribute is kept as the list of lines still being accumulated
  # when the file ends; join it back so it can be checked like any other value.
  defp to_code(value) when is_list(value), do: Enum.join(Enum.reverse(value), "\n")
  defp to_code(value), do: value

  # `Pythelix.World.File` reports a problem in the shape of the file itself —
  # a line that is neither an entity header, an attribute nor a method. It
  # already carries the line and the offending text, so keep its message.
  defp structural(path, reason) do
    {line, message} = split_reason(reason)

    %Diagnostic{
      file: path,
      context: nil,
      line: line,
      column: nil,
      message: message,
      hint: nil,
      doc: "worldlets.md",
      source: nil
    }
  end

  defp split_reason(reason) do
    case Regex.run(~r/line (\d+)\n(.*)/s, reason) do
      [_, line, rest] -> {String.to_integer(line), rest |> String.trim() |> first_line()}
      nil -> {1, String.trim(reason)}
    end
  end

  defp first_line(text), do: text |> String.split("\n") |> List.first()
end
