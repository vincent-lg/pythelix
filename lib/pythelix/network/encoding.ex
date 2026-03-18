defmodule Pythelix.Network.Encoding do
  @moduledoc """
  Handles encoding/decoding of text for TCP clients.

  Internally, Elixir works with UTF-8. Clients may use different encodings
  (e.g. CP1252, ISO-8859-15). This module converts between the client's
  encoding and UTF-8, replacing unmappable characters with "?".
  """

  @supported_encodings %{
    "utf-8" => nil,
    "iso-8859-15" => "ISO8859/8859-15",
    "iso-8859-1" => "ISO8859/8859-1",
    "cp1252" => "VENDORS/MICSFT/WINDOWS/CP1252"
  }

  @doc """
  Returns the list of supported encoding names.
  """
  def supported_encodings, do: Map.keys(@supported_encodings)

  @doc """
  Returns true if the given encoding name is supported.
  """
  def supported?(encoding) do
    Map.has_key?(@supported_encodings, normalize(encoding))
  end

  @doc """
  Decode incoming bytes from the client encoding to UTF-8.
  Unmappable bytes are replaced with "?".
  """
  def decode(data, encoding) do
    case Map.get(@supported_encodings, normalize(encoding)) do
      nil ->
        # UTF-8 (or unknown): keep as-is, but sanitize invalid sequences
        sanitize_utf8(data)

      codepage ->
        case Codepagex.to_string(data, codepage, Codepagex.replace_nonexistent("?")) do
          {:ok, string, _} -> string
          {:ok, string} -> string
          {:error, _} -> sanitize_utf8(data)
        end
    end
  end

  @doc """
  Encode outgoing UTF-8 text to the client's encoding.
  Unmappable characters are replaced with "?".
  """
  def encode(text, encoding) do
    case Map.get(@supported_encodings, normalize(encoding)) do
      nil ->
        # UTF-8: no conversion needed
        text

      codepage ->
        case Codepagex.from_string(text, codepage, Codepagex.replace_nonexistent("?")) do
          {:ok, binary, _} -> binary
          {:ok, binary} -> binary
          {:error, _} -> text
        end
    end
  end

  defp normalize(encoding) when is_binary(encoding) do
    encoding |> String.downcase() |> String.trim()
  end

  defp normalize(_), do: "utf-8"

  defp sanitize_utf8(data) do
    case :unicode.characters_to_binary(data, :utf8) do
      {:error, valid, _rest} -> valid <> "?"
      {:incomplete, valid, _rest} -> valid <> "?"
      binary when is_binary(binary) -> binary
    end
  end
end
