defmodule Pythelix.Scripting.Namespace.String do
  @moduledoc """
  Module defining the string object with its attributes and methods.

  Note: in Python (and in this scripting language), strings do not have references.
  They don't hold attributes and their methods always return the modified string.
  """

  use Pythelix.Scripting.Namespace

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    {script, String.contains?(namespace.self, namespace.element)}
  end

  defmet __repr__(script, namespace), [] do
    {script, inspect(namespace.self)}
  end

  defmet __str__(script, namespace), [] do
    {script, namespace.self}
  end

  defmet capitalize(script, namespace), [] do
    {script, String.capitalize(namespace.self)}
  end

  defmet center(script, namespace), [
    {:width, index: 0, type: :int},
    {:fill_char, index: 1, type: :str, default: " "}
  ] do
    {script, adjust(namespace.self, namespace.width, namespace.fill_char, :center)}
  end

  defmet count(script, namespace), [
    {:sub, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    {script, count(namespace.self, namespace.sub, namespace.start, namespace.end)}
  end

  defmet endswith(script, namespace), [
    {:suffix, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    {script, string_endswith(namespace.self, namespace.suffix, namespace.start, namespace.end)}
  end

  defmet find(script, namespace), [
    {:sub, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    {script, string_find(namespace.self, namespace.sub, namespace.start, namespace.end)}
  end

  defmet index(script, namespace), [
    {:sub, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    case string_find(namespace.self, namespace.sub, namespace.start, namespace.end) do
      -1 ->
        {Script.raise(script, ValueError, "substring not found"), :none}

      pos ->
        {script, pos}
    end
  end

  defmet isalnum(script, namespace), [] do
    {script, string_isalnum(namespace.self)}
  end

  defmet isalpha(script, namespace), [] do
    {script, string_isalpha(namespace.self)}
  end

  defmet isascii(script, namespace), [] do
    {script, string_isascii(namespace.self)}
  end

  defmet isdecimal(script, namespace), [] do
    {script, string_isdecimal(namespace.self)}
  end

  defmet isdigit(script, namespace), [] do
    {script, string_isdigit(namespace.self)}
  end

  defmet isidentifier(script, namespace), [] do
    {script, string_isidentifier(namespace.self)}
  end

  defmet islower(script, namespace), [] do
    {script, string_islower(namespace.self)}
  end

  defmet isnumeric(script, namespace), [] do
    {script, string_isnumeric(namespace.self)}
  end

  defmet isprintable(script, namespace), [] do
    {script, string_isprintable(namespace.self)}
  end

  defmet isspace(script, namespace), [] do
    {script, string_isspace(namespace.self)}
  end

  defmet istitle(script, namespace), [] do
    {script, string_istitle(namespace.self)}
  end

  defmet isupper(script, namespace), [] do
    {script, string_isupper(namespace.self)}
  end

  defmet join(script, namespace), [
    {:iterable, index: 0, type: :list}
  ] do
    Store.get_value(namespace.iterable, recursive: false)
    |> Enum.with_index()
    |> Enum.reduce_while({script, []}, fn {element, index}, {script, items} ->
      if is_binary(element) do
        {:cont, {script, [element | items]}}
      else
        message = "sequence item #{index}: expected str"
        {:halt, {Script.raise(script, TypeError, message), nil}}
      end
    end)
    |> then(fn
      {%Script{error: error} = script, _} when error != nil ->
        {script, :none}

      {script, iterable} ->
        {script, string_join(namespace.self, Enum.reverse(iterable))}
    end)
  end

  defmet ljust(script, namespace), [
    {:width, index: 0, type: :int},
    {:fill_char, index: 1, type: :str, default: " "}
  ] do
    {script, adjust(namespace.self, namespace.width, namespace.fill_char, :left)}
  end

  defmet lower(script, namespace), [] do
    {script, String.downcase(namespace.self)}
  end

  defmet lstrip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, lstrip(namespace.self, namespace.chars)}
  end

  defmet removeprefix(script, namespace), [
    {:prefix, index: 0, type: :str}
  ] do
    {script, string_removeprefix(namespace.self, namespace.prefix)}
  end

  defmet removesuffix(script, namespace), [
    {:suffix, index: 0, type: :str}
  ] do
    {script, string_removesuffix(namespace.self, namespace.suffix)}
  end

  defmet replace(script, namespace), [
    {:old, index: 0, type: :str},
    {:new, index: 1, type: :str},
    {:count, index: 2, type: :int, default: -1}
  ] do
    {script, string_replace(namespace.self, namespace.old, namespace.new, namespace.count)}
  end

  defmet rfind(script, namespace), [
    {:sub, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    {script, string_rfind(namespace.self, namespace.sub, namespace.start, namespace.end)}
  end

  defmet rindex(script, namespace), [
    {:sub, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    case string_rfind(namespace.self, namespace.sub, namespace.start, namespace.end) do
      -1 ->
        {Script.raise(script, ValueError, "substring not found"), :none}

      pos ->
        {script, pos}
    end
  end

  defmet rjust(script, namespace), [
    {:width, index: 0, type: :int},
    {:fill_char, index: 1, type: :str, default: " "}
  ] do
    {script, adjust(namespace.self, namespace.width, namespace.fill_char, :right)}
  end

  defmet rsplit(script, namespace), [
    {:sep, index: 0, type: :str, default: nil},
    {:maxsplit, index: 1, type: :int, default: -1}
  ] do
    {script, string_rsplit(namespace.self, namespace.sep, namespace.maxsplit)}
  end

  defmet rstrip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, rstrip(namespace.self, namespace.chars)}
  end

  defmet split(script, namespace), [
    {:sep, index: 0, type: :str, default: nil},
    {:maxsplit, index: 1, type: :int, default: -1}
  ] do
    {script, string_split(namespace.self, namespace.sep, namespace.maxsplit)}
  end

  defmet splitlines(script, namespace), [
    {:keepends, index: 0, type: :bool, default: false}
  ] do
    {script, string_splitlines(namespace.self, namespace.keepends)}
  end

  defmet startswith(script, namespace), [
    {:prefix, index: 0, type: :str},
    {:start, index: 1, type: :int, default: 0},
    {:end, index: 2, type: :int, default: nil}
  ] do
    {script, string_startswith(namespace.self, namespace.prefix, namespace.start, namespace.end)}
  end

  defmet strip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, strip(namespace.self, namespace.chars)}
  end

  defmet title(script, namespace), [] do
    {script, title(namespace.self)}
  end

  defmet upper(script, namespace), [] do
    {script, String.upcase(namespace.self)}
  end

  # Helper functions
  defp adjust(string, width, fill_char, dir) do
    adjust(string, width, fill_char, dir, String.length(string))
  end

  defp adjust(string, width, _fill, _dir, cur) when cur >= width, do: string

  defp adjust(string, width, fill, :right, cur) do
    String.duplicate(fill, width - cur) <> string
  end

  defp adjust(string, width, fill, :left, cur) do
    string <> String.duplicate(fill, width - cur)
  end

  defp adjust(string, width, fill, :center, cur) do
    prefix = String.duplicate(fill, div(width - cur, 2) + rem(width - cur, 2))
    suffix = String.duplicate(fill, div(width - cur, 2))

    prefix <> string <> suffix
  end

  defp count(string, sub, start, d_end) do
    length =
      if d_end == nil do
        String.length(string) - start
      else
        d_end - start
      end

    chunk =
      string
      |> String.slice(start, length)

    {_, number} = count_chunks(chunk, sub, 0)

    number
  end

  defp count_chunks("", _sub, number), do: {"", number}

  defp count_chunks(chunk, sub, number) do
    case String.starts_with?(chunk, sub) do
      true ->
        len = String.length(sub)

        chunk
        |> String.slice(len, String.length(chunk) - len)
        |> count_chunks(sub, number + 1)

      false ->
        chunk
        |> String.slice(1, String.length(chunk) - 1)
        |> count_chunks(sub, number)
    end
  end

  defp string_endswith(string, suffix, start, d_end) do
    slice = get_slice(string, start, d_end)
    String.ends_with?(slice, suffix)
  end

  defp string_startswith(string, prefix, start, d_end) do
    slice = get_slice(string, start, d_end)
    String.starts_with?(slice, prefix)
  end

  defp string_find(string, sub, start, d_end) do
    slice = get_slice(string, start, d_end)

    case String.split(slice, sub, parts: 2) do
      [before, _] -> start + String.length(before)
      [_] -> -1
    end
  end

  defp string_rfind(string, sub, start, d_end) do
    slice = get_slice(string, start, d_end)
    parts = String.split(slice, sub)

    case length(parts) do
      1 ->
        -1

      n ->
        parts_before_last = Enum.take(parts, n - 1)

        before_length =
          Enum.reduce(parts_before_last, 0, fn part, acc ->
            acc + String.length(part) + String.length(sub)
          end) - String.length(sub)

        start + before_length
    end
  end

  defp get_slice(string, start, nil) do
    String.slice(string, start..-1//1)
  end

  defp get_slice(_string, start, d_end) when d_end <= start do
    ""
  end

  defp get_slice(string, start, d_end) do
    String.slice(string, start, d_end - start)
  end

  defp string_isalnum(string) do
    String.length(string) > 0 and
      String.codepoints(string)
      |> Enum.all?(fn cp ->
        String.match?(cp, ~r/^[[:alnum:]]$/u)
      end)
  end

  defp string_isalpha(string) do
    String.length(string) > 0 and
      String.codepoints(string)
      |> Enum.all?(fn cp ->
        String.match?(cp, ~r/^[[:alpha:]]$/u)
      end)
  end

  defp string_isascii(string) do
    String.codepoints(string)
    |> Enum.all?(fn cp ->
      <<codepoint::utf8>> = cp
      codepoint <= 127
    end)
  end

  defp string_isdecimal(string) do
    String.length(string) > 0 and
      String.codepoints(string)
      |> Enum.all?(fn cp ->
        String.match?(cp, ~r/^[0-9]$/)
      end)
  end

  defp string_isdigit(string) do
    String.length(string) > 0 and
      String.codepoints(string)
      |> Enum.all?(fn cp ->
        String.match?(cp, ~r/^[[:digit:]]$/u)
      end)
  end

  defp string_isidentifier(string) do
    String.length(string) > 0 and
      String.match?(string, ~r/^[[:alpha:]_][[:alnum:]_]*$/u)
  end

  defp string_islower(string) do
    has_cased =
      String.codepoints(string)
      |> Enum.any?(fn cp ->
        String.match?(cp, ~r/^[[:alpha:]]$/u)
      end)

    has_cased and string == String.downcase(string)
  end

  defp string_isnumeric(string) do
    String.length(string) > 0 and
      String.codepoints(string)
      |> Enum.all?(fn cp ->
        String.match?(cp, ~r/^[[:digit:]]$/u)
      end)
  end

  defp string_isprintable(string) do
    String.codepoints(string)
    |> Enum.all?(fn cp ->
      String.match?(cp, ~r/^[[:print:]]$/u) or cp == "\t"
    end)
  end

  defp string_isspace(string) do
    String.length(string) > 0 and String.trim(string) == ""
  end

  defp string_istitle(string) do
    words = String.split(string, ~r/\s+/)
    has_words = length(words) > 0

    has_words and
      Enum.all?(words, fn word ->
        case String.codepoints(word) do
          [] ->
            true

          [first | rest] ->
            first_is_upper =
              String.match?(first, ~r/^[[:upper:]]$/u) or
                not String.match?(first, ~r/^[[:alpha:]]$/u)

            rest_is_lower =
              Enum.all?(rest, fn cp ->
                not String.match?(cp, ~r/^[[:alpha:]]$/u) or String.match?(cp, ~r/^[[:lower:]]$/u)
              end)

            first_is_upper and rest_is_lower
        end
      end)
  end

  defp string_isupper(string) do
    has_cased =
      String.codepoints(string)
      |> Enum.any?(fn cp ->
        String.match?(cp, ~r/^[[:alpha:]]$/u)
      end)

    has_cased and string == String.upcase(string)
  end

  defp string_join(separator, iterable) do
    list = iterable

    string_list =
      Enum.map(list, fn item ->
        case item do
          str when is_binary(str) -> str
          _ -> inspect(item)
        end
      end)

    Enum.join(string_list, separator)
  end

  defp string_removeprefix(string, prefix) do
    if String.starts_with?(string, prefix) do
      String.slice(string, String.length(prefix)..-1//1)
    else
      string
    end
  end

  defp string_removesuffix(string, suffix) do
    if String.ends_with?(string, suffix) do
      suffix_len = String.length(suffix)
      String.slice(string, 0, String.length(string) - suffix_len)
    else
      string
    end
  end

  defp string_replace(string, old, new, count) when count == -1 do
    String.replace(string, old, new, global: true)
  end

  defp string_replace(string, old, new, count) when count >= 0 do
    do_replace(string, old, new, count, "")
  end

  defp do_replace(string, _old, _new, 0, acc), do: acc <> string
  defp do_replace("", _old, _new, _count, acc), do: acc

  defp do_replace(string, old, new, count, acc) do
    case String.split(string, old, parts: 2) do
      [before, rest] ->
        do_replace(rest, old, new, count - 1, acc <> before <> new)

      [_] ->
        acc <> string
    end
  end

  defp string_split(string, nil, maxsplit) do
    trimmed = String.trim(string)

    if trimmed == "" do
      []
    else
      parts = String.split(trimmed, ~r/\s+/)

      if maxsplit == -1 do
        parts
      else
        limit_splits(parts, maxsplit)
      end
    end
  end

  defp string_split(string, sep, maxsplit) when maxsplit == -1 do
    String.split(string, sep)
  end

  defp string_split(string, sep, maxsplit) do
    parts = String.split(string, sep, parts: maxsplit + 1)
    parts
  end

  defp string_rsplit(string, nil, maxsplit) do
    parts = string_split(string, nil, -1)

    if maxsplit == -1 do
      parts
    else
      reverse_limit_splits_space(parts, maxsplit)
    end
  end

  defp string_rsplit(string, sep, maxsplit) when maxsplit == -1 do
    String.split(string, sep)
  end

  defp string_rsplit(string, sep, maxsplit) do
    parts = String.split(string, sep)
    reverse_limit_splits_sep(parts, maxsplit, sep)
  end

  defp limit_splits(parts, maxsplit) when length(parts) <= maxsplit + 1, do: parts

  defp limit_splits(parts, maxsplit) do
    {keep, rest} = Enum.split(parts, maxsplit)
    keep ++ [Enum.join(rest, " ")]
  end

  defp reverse_limit_splits_space(parts, maxsplit) when length(parts) <= maxsplit + 1, do: parts

  defp reverse_limit_splits_space(parts, maxsplit) do
    {rest, keep} = Enum.split(parts, length(parts) - maxsplit)
    [Enum.join(rest, " ")] ++ keep
  end

  defp reverse_limit_splits_sep(parts, maxsplit, _sep) when length(parts) <= maxsplit + 1,
    do: parts

  defp reverse_limit_splits_sep(parts, maxsplit, sep) do
    {rest, keep} = Enum.split(parts, length(parts) - maxsplit)
    [Enum.join(rest, sep)] ++ keep
  end

  defp string_splitlines(string, keepends) do
    case keepends do
      false ->
        String.split(string, ~r/\r\n|\r|\n/)

      _ ->
        Regex.scan(~r/.*?(?:\r\n|\r|\n|$)/, string)
        |> List.flatten()
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp strip(string, chars) do
    string
    |> lstrip(chars)
    |> rstrip(chars)
  end

  defp lstrip(string, chars) do
    chars_set = MapSet.new(String.codepoints(chars))

    string
    |> String.codepoints()
    |> ltrim_chars(chars_set)
    |> Enum.join()
  end

  def rstrip(string, chars) do
    chars_set = MapSet.new(String.codepoints(chars))

    string
    |> String.codepoints()
    |> Enum.reverse()
    |> ltrim_chars(chars_set)
    |> Enum.reverse()
    |> Enum.join()
  end

  defp ltrim_chars([], _chars_set), do: []

  defp ltrim_chars([head | tail] = list, chars_set) do
    cond do
      MapSet.member?(chars_set, head) ->
        ltrim_chars(tail, chars_set)

      true ->
        list
    end
  end

  defp title(string) do
    string
    |> String.split(~r{\s}, include_captures: true)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
  end
end
