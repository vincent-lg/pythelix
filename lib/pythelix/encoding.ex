defmodule Pythelix.Encoding do
  @moduledoc """
  Read the files a builder writes, whatever their editor produced.

  Worldlets and scenarios are written by hand, often on Windows, often in a
  language with accented characters. Two things vary and neither should ever
  break a file:

    * **The encoding.** Elixir works in UTF-8, but an editor may well have
      saved Latin-1 or CP1252 — on Windows, without saying so. The game
      already knows which encoding to expect for its players
      (`PYTHELIX_DEFAULT_ENCODING`, see `Pythelix.Network.Encoding`), and the
      same answer applies to the files they write.

    * **The line endings.** A file written on Windows ends its lines with
      CRLF. Left alone, every line of it would end in a stray carriage return,
      and every comparison against it would fail for reasons invisible on
      screen.

  A file that is valid UTF-8 is always read as UTF-8, whatever the configured
  encoding says — that is the common case, and guessing against the evidence
  would corrupt it.
  """

  alias Pythelix.Network.Encoding

  @doc """
  Read a file as UTF-8 text with normalised line endings.

  Raises like `File.read!/1` if the file cannot be read.
  """
  @spec read_file!(binary()) :: binary()
  def read_file!(path) do
    path
    |> File.read!()
    |> decode()
    |> normalize_newlines()
  end

  @doc """
  Decode bytes to UTF-8, honouring the configured default encoding.

  Content that is already valid UTF-8 is returned untouched.
  """
  @spec decode(binary()) :: binary()
  def decode(content) do
    cond do
      String.valid?(content) -> strip_bom(content)
      true -> content |> Encoding.decode(default_encoding()) |> strip_bom()
    end
  end

  @doc """
  Turn CRLF and lone CR line endings into LF.
  """
  @spec normalize_newlines(binary()) :: binary()
  def normalize_newlines(content), do: String.replace(content, ~r/\r\n?/, "\n")

  # Windows editors like to announce UTF-8 with a byte-order mark. It is
  # invisible in the editor and would otherwise become part of the first line.
  defp strip_bom("﻿" <> rest), do: rest
  defp strip_bom(content), do: content

  defp default_encoding, do: Application.get_env(:pythelix, :default_encoding, "utf-8")
end
