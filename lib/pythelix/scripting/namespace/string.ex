defmodule Pythelix.Scripting.Namespace.String do
  @moduledoc """
  Module defining the string object with its attributes and methods.

  Note: in Python (and in this scripting language), strings do not have references.
  They don't hold attributes and their methods always return the modified string.
  """

  use Pythelix.Scripting.Namespace

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

  defmet ljust(script, namespace), [
    {:width, index: 0, type: :int},
    {:fill_char, index: 1, type: :str, default: " "}
  ] do
    {script, adjust(namespace.self, namespace.width, namespace.fill_char, :left)}
  end

  defmet lower(script, self, _args, _kwargs) do
    string = Script.get_value(script, self)

    {script, String.downcase(string)}
  end

  defmet lstrip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, lstrip(namespace.self, namespace.chars)}
  end

  defmet strip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, strip(namespace.self, namespace.chars)}
  end

  defmet rjust(script, namespace), [
    {:width, index: 0, type: :int},
    {:fill_char, index: 1, type: :str, default: " "}
  ] do
    {script, adjust(namespace.self, namespace.width, namespace.fill_char, :right)}
  end

  defmet rstrip(script, namespace), [
    {:chars, index: 0, type: :str, default: " \n"}
  ] do
    {script, rstrip(namespace.self, namespace.chars)}
  end

  defmet title(script, namespace), [] do
    {script, title(namespace.self)}
  end

  defmet upper(script, self, _args, _kwargs) do
    string = Script.get_value(script, self)

    {script, String.upcase(string)}
  end

  # Helper functions
  defp adjust(string, width, fill_char, dir) do
    adjust(string, width, fill_char, dir, String.length(string))
  end

  defp adjust(string, width, _fill, :left, cur) when cur >= width, do: string

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
