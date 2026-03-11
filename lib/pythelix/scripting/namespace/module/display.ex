defmodule Pythelix.Scripting.Namespace.Module.Display do
  @moduledoc """
  Module defining the display module for formatting output.

  Provides `HorizontalList` for columnar formatting, and `dedent`, `wrap`,
  and `fill` inspired by Python's `textwrap` module.
  """

  use Pythelix.Scripting.Module, name: "display"

  alias Pythelix.Scripting.Object.HorizontalList

  deffun function_HorizontalList(script, namespace), [
    {:indent, keyword: "indent", type: :int, default: 2},
    {:columns, keyword: "columns", type: :int, default: 3},
    {:col_width, keyword: "col_width", type: :int, default: 20}
  ] do
    list = %HorizontalList{
      indent: namespace.indent,
      columns: namespace.columns,
      col_width: namespace.col_width
    }

    {script, list}
  end

  deffun dedent(script, namespace), [
    {:text, index: 0, type: :str}
  ] do
    {script, dedent(namespace.text)}
  end

  deffun wrap(script, namespace), [
    {:text, index: 0, type: :str},
    {:width, keyword: "width", type: :int, default: 70},
    {:initial_indent, keyword: "initial_indent", type: :str, default: ""},
    {:subsequent_indent, keyword: "subsequent_indent", type: :str, default: ""},
    {:replace_whitespace, keyword: "replace_whitespace", type: :bool, default: true},
    {:drop_whitespace, keyword: "drop_whitespace", type: :bool, default: true},
    {:break_long_words, keyword: "break_long_words", type: :bool, default: true},
    {:break_on_hyphens, keyword: "break_on_hyphens", type: :bool, default: true},
    {:max_lines, keyword: "max_lines", type: :int, default: 0},
    {:placeholder, keyword: "placeholder", type: :str, default: " [...]"}
  ] do
    lines =
      do_wrap(namespace.text, %{
        width: namespace.width,
        initial_indent: namespace.initial_indent,
        subsequent_indent: namespace.subsequent_indent,
        replace_whitespace: namespace.replace_whitespace,
        drop_whitespace: namespace.drop_whitespace,
        break_long_words: namespace.break_long_words,
        break_on_hyphens: namespace.break_on_hyphens,
        max_lines: namespace.max_lines,
        placeholder: namespace.placeholder
      })

    {script, lines}
  end

  deffun fill(script, namespace), [
    {:text, index: 0, type: :str},
    {:width, keyword: "width", type: :int, default: 70},
    {:initial_indent, keyword: "initial_indent", type: :str, default: ""},
    {:subsequent_indent, keyword: "subsequent_indent", type: :str, default: ""},
    {:replace_whitespace, keyword: "replace_whitespace", type: :bool, default: true},
    {:drop_whitespace, keyword: "drop_whitespace", type: :bool, default: true},
    {:break_long_words, keyword: "break_long_words", type: :bool, default: true},
    {:break_on_hyphens, keyword: "break_on_hyphens", type: :bool, default: true},
    {:max_lines, keyword: "max_lines", type: :int, default: 0},
    {:placeholder, keyword: "placeholder", type: :str, default: " [...]"}
  ] do
    result =
      namespace.text
      |> do_wrap(%{
        width: namespace.width,
        initial_indent: namespace.initial_indent,
        subsequent_indent: namespace.subsequent_indent,
        replace_whitespace: namespace.replace_whitespace,
        drop_whitespace: namespace.drop_whitespace,
        break_long_words: namespace.break_long_words,
        break_on_hyphens: namespace.break_on_hyphens,
        max_lines: namespace.max_lines,
        placeholder: namespace.placeholder
      })
      |> Enum.join("\n")

    {script, result}
  end

  defp dedent(text) do
    lines = String.split(text, "\n")

    min_indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn line ->
        String.length(line) - String.length(String.trim_leading(line))
      end)
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(fn line ->
      if String.trim(line) == "" do
        ""
      else
        String.slice(line, min_indent..-1//1)
      end
    end)
    |> Enum.join("\n")
  end

  defp do_wrap(text, opts) do
    text =
      if opts.replace_whitespace do
        String.replace(text, ~r/[\t\n\v\f\r]/, " ")
      else
        text
      end

    chunks = split_chunks(text, opts.break_on_hyphens)
    lines = build_lines(chunks, opts, [], "", true)

    lines =
      if opts.max_lines > 0 and length(lines) > opts.max_lines do
        truncated = Enum.take(lines, opts.max_lines)
        last = List.last(truncated)
        rest = Enum.take(truncated, opts.max_lines - 1)

        trimmed_last = String.trim_trailing(last)

        last_with_placeholder =
          if String.length(trimmed_last) + String.length(opts.placeholder) <= opts.width do
            trimmed_last <> opts.placeholder
          else
            # Try to fit placeholder by removing words from the end.
            fit_placeholder(trimmed_last, opts)
          end

        rest ++ [last_with_placeholder]
      else
        lines
      end

    lines
  end

  defp fit_placeholder(line, opts) do
    words = String.split(line)
    indent = if length(words) > 0, do: get_indent(line), else: ""
    fit_placeholder_words(words, indent, opts)
  end

  defp fit_placeholder_words([], indent, opts),
    do: String.trim_trailing(indent) <> opts.placeholder

  defp fit_placeholder_words(words, indent, opts) do
    candidate = indent <> Enum.join(words, " ")

    if String.length(candidate) + String.length(opts.placeholder) <= opts.width do
      candidate <> opts.placeholder
    else
      fit_placeholder_words(Enum.take(words, length(words) - 1), indent, opts)
    end
  end

  defp get_indent(line) do
    case Regex.run(~r/^(\s*)/, line) do
      [_, indent] -> indent
      _ -> ""
    end
  end

  # Split text into chunks (words and whitespace), respecting hyphens.
  defp split_chunks(text, break_on_hyphens) do
    if break_on_hyphens do
      # Split on whitespace boundaries and after hyphens within words.
      Regex.split(~r/(\s+)/, text, include_captures: true)
      |> Enum.flat_map(fn chunk ->
        if String.match?(chunk, ~r/^\s+$/) do
          [chunk]
        else
          # Split after hyphens but keep them attached to the preceding part.
          split_on_hyphens(chunk)
        end
      end)
    else
      Regex.split(~r/(\s+)/, text, include_captures: true)
    end
  end

  defp split_on_hyphens(word) do
    # Split compound words like "well-known" into ["well-", "known"].
    parts = Regex.split(~r/(-+)/, word, include_captures: true)

    case parts do
      [_single] -> [word]
      _ -> merge_hyphen_parts(parts, [])
    end
  end

  # Merge hyphen delimiters with their preceding word part:
  # ["well", "-", "known"] -> ["well-", "known"]
  defp merge_hyphen_parts([], acc), do: Enum.reverse(acc)
  defp merge_hyphen_parts([last], acc), do: Enum.reverse([last | acc])

  defp merge_hyphen_parts([part, hyphen | rest], acc) do
    merge_hyphen_parts(rest, [part <> hyphen | acc])
  end

  defp build_lines([], opts, lines, current, _first) do
    current = apply_drop_whitespace(current, opts.drop_whitespace)
    if current == "" and lines == [], do: [], else: Enum.reverse([current | lines])
  end

  defp build_lines([chunk | rest], opts, lines, current, first) do
    is_space = String.match?(chunk, ~r/^\s+$/)

    cond do
      is_space and current == "" ->
        # Leading whitespace on a new line — skip if drop_whitespace.
        if opts.drop_whitespace do
          build_lines(rest, opts, lines, current, first)
        else
          build_lines(rest, opts, lines, chunk, first)
        end

      is_space ->
        # Whitespace within a line — just append.
        build_lines(rest, opts, lines, current <> chunk, first)

      true ->
        indent = if first, do: opts.initial_indent, else: opts.subsequent_indent
        candidate = if current == "", do: indent <> chunk, else: current <> chunk

        if String.length(candidate) <= opts.width do
          build_lines(rest, opts, lines, candidate, first)
        else
          if current == "" or String.trim(current) == "" do
            # Word is too long for a line on its own.
            if opts.break_long_words do
              {broken_lines, leftover} = break_word(indent <> chunk, opts.width)

              new_lines =
                broken_lines
                |> Enum.reverse()
                |> Enum.reduce(lines, fn l, acc -> [l | acc] end)

              build_lines(rest, opts, new_lines, leftover, false)
            else
              # Don't break — just put the long word on its own line.
              build_lines(rest, opts, lines, indent <> chunk, first)
            end
          else
            # Wrap: finish current line and start a new one.
            finished = apply_drop_whitespace(current, opts.drop_whitespace)
            new_indent = opts.subsequent_indent
            build_lines([chunk | rest], opts, [finished | lines], new_indent, false)
          end
        end
    end
  end

  defp apply_drop_whitespace(line, true), do: String.trim_trailing(line)
  defp apply_drop_whitespace(line, false), do: line

  defp break_word(word, width) when width <= 0, do: {[], word}

  defp break_word(word, width) do
    if String.length(word) <= width do
      {[], word}
    else
      {first, rest} = String.split_at(word, width)
      {more_lines, leftover} = break_word(rest, width)
      {[first | more_lines], leftover}
    end
  end
end
