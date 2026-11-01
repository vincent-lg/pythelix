defmodule Pythelix.Encoding do
  @moduledoc """
  Read the files a builder writes, whatever their editor produced.

  Worldlets and scenarios are written by hand, often on Windows, often in a
  language with accented characters. Two things vary and neither should ever
  break a file:

    * **The encoding.** Elixir works in UTF-8, but an editor may well have
      saved Latin-1 or CP1252 — on Windows, without saying so. Each file is
      tried as UTF-8 first: UTF-8 is strict about byte shapes, so a file
      saved in a single-byte encoding fails on its first accented character
      rather than decoding into nonsense. Only then is the file decoded with
      `WORLDLETS_ENCODING` (or, when that is empty, `DEFAULT_ENCODING`, the
      encoding the game expects from its players; see
      `Pythelix.Network.Encoding`). The decision is made per file, because
      one builder's editor is not another's.

    * **The line endings.** A file written on Windows ends its lines with
      CRLF. Left alone, every line of it would end in a stray carriage return,
      and every comparison against it would fail for reasons invisible on
      screen.

  A file that needed the fallback is reported (see `notice/2`), because the
  builder should learn their editor is saving in the wrong encoding rather
  than have it papered over forever.
  """

  alias Pythelix.Network.Encoding

  require Logger

  @utf8 "utf-8"

  @doc """
  Read a file as UTF-8 text with normalised line endings.

  Returns the text and the encoding it was read with: `"utf-8"`, or the
  configured fallback when the file wasn't valid UTF-8.

  Raises like `File.read!/1` if the file cannot be read.
  """
  @spec read_file(binary()) :: {binary(), binary()}
  def read_file(path) do
    {text, encoding} = path |> File.read!() |> decode_with()

    {normalize_newlines(text), encoding}
  end

  @doc """
  Read a file as UTF-8 text with normalised line endings, logging a warning
  when the file had to be decoded with the fallback encoding.

  For callers that only want the text. Those that report to a builder (the
  worldlet loader and checker) use `read_file/1` and pass the notice on.
  """
  @spec read_file!(binary()) :: binary()
  def read_file!(path) do
    case read_file(path) do
      {text, @utf8} ->
        text

      {text, encoding} ->
        Logger.warning(notice(path, encoding))
        text
    end
  end

  @doc """
  Decode bytes to UTF-8, honouring the configured fallback encoding.

  Content that is already valid UTF-8 is returned untouched.
  """
  @spec decode(binary()) :: binary()
  def decode(content), do: content |> decode_with() |> elem(0)

  @doc """
  Decode bytes to UTF-8 and say which encoding was used.
  """
  @spec decode_with(binary()) :: {binary(), binary()}
  def decode_with(content) do
    if String.valid?(content) do
      {strip_bom(content), @utf8}
    else
      encoding = fallback_encoding()
      {content |> Encoding.decode(encoding) |> strip_bom(), encoding}
    end
  end

  @doc """
  The sentence shown to a builder whose file wasn't UTF-8.
  """
  @spec notice(binary(), binary()) :: binary()
  def notice(path, encoding) do
    "#{Pythelix.Paths.display(path)} is not UTF-8 and was read as #{encoding}. " <>
      "Save it as UTF-8 so that it reads the same everywhere."
  end

  @doc """
  Turn CRLF and lone CR line endings into LF.
  """
  @spec normalize_newlines(binary()) :: binary()
  def normalize_newlines(content), do: String.replace(content, ~r/\r\n?/, "\n")

  @doc """
  The encoding a file is decoded with when it isn't valid UTF-8.

  `WORLDLETS_ENCODING` when set, else the players' `DEFAULT_ENCODING`.
  """
  @spec fallback_encoding() :: binary()
  def fallback_encoding do
    Application.get_env(:pythelix, :worldlets_encoding) ||
      Application.get_env(:pythelix, :default_encoding, @utf8)
  end

  # Windows editors like to announce UTF-8 with a byte-order mark. It is
  # invisible in the editor and would otherwise become part of the first line.
  defp strip_bom("﻿" <> rest), do: rest
  defp strip_bom(content), do: content
end
