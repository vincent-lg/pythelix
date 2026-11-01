defmodule Pythelix.Settings do
  @moduledoc """
  The game's settings file: `settings.txt` next to the worldlets.

  This is the one file a game administrator edits to configure the engine
  without touching an environment variable or a release script. It is read
  by `config/runtime.exs` before anything else starts, so it can only hold
  what the engine needs *before* the world is loaded: where the files are,
  which ports to listen on, how files and players are encoded, and the keys
  of the generic entities. Anything about how the game behaves belongs in a
  worldlet, where methods and inheritance are available.

  The format is deliberately plain so that it survives Notepad:

      # A comment.
      NAME=value

  One setting per line; blank lines and lines starting with `#` are ignored;
  spaces around the `=` don't matter; CRLF line endings and a UTF-8 byte-order
  mark are tolerated. An environment variable of the same name takes
  precedence over the line in the file, so a deployment script can still
  override a setting without editing it.
  """

  alias Pythelix.Network.Encoding

  @file_name "settings.txt"

  @doc "The name of the settings file, `settings.txt`."
  @spec file_name() :: binary()
  def file_name, do: @file_name

  @doc "Where the settings file lives for a game rooted at `base_dir`."
  @spec path(binary()) :: binary()
  def path(base_dir), do: Path.join(base_dir, @file_name)

  @doc """
  Parse the text of a settings file into a map of `NAME => value`.

  Unknown names are kept: the file is the administrator's, and a line the
  engine doesn't understand is not a reason to refuse to start. A line
  without `=` is ignored.
  """
  @spec parse(binary()) :: %{binary() => binary()}
  def parse(text) do
    text
    |> decode()
    |> String.split(~r/\r\n?|\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.flat_map(fn line ->
      case String.split(line, "=", parts: 2) do
        [key, value] -> [{String.trim(key), String.trim(value)}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  @doc """
  Read and parse a settings file.

  Returns `:nofile` when there is none, which the caller treats as "use the
  defaults" rather than as an error.
  """
  @spec read(binary()) :: {:ok, %{binary() => binary()}} | :nofile
  def read(path) do
    case File.read(path) do
      {:ok, text} -> {:ok, parse(text)}
      {:error, _} -> :nofile
    end
  end

  @doc """
  Read the settings file at `path`, writing a commented default one first if
  it doesn't exist.

  `seed` supplies values for the generated file (a secret key base carried
  over from an older installation, say); the defaults fill in the rest.
  """
  @spec ensure!(binary(), %{optional(binary()) => binary()}) :: %{binary() => binary()}
  def ensure!(path, seed \\ %{}) do
    case read(path) do
      {:ok, settings} ->
        settings

      :nofile ->
        IO.puts("Generating the settings file: #{path}")
        contents = default_contents(seed)
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, contents)
        parse(contents)
    end
  end

  @doc """
  The text of a freshly generated settings file.

  Every setting is present, with its default and a comment saying what it
  does, so that an administrator can change one without looking anything up.
  """
  @spec default_contents(%{optional(binary()) => binary()}) :: binary()
  def default_contents(seed \\ %{}) do
    get = fn key, default -> Map.get(seed, key) || default end
    encodings = Encoding.supported_encodings() |> Enum.sort() |> Enum.join(", ")

    """
    # Pythelix settings.
    #
    # One setting per line, written as NAME=value. Lines starting with # are
    # comments. Changes take effect the next time the server starts.
    # An environment variable with the same name overrides the line here.
    #
    # Relative paths are relative to the directory holding this file.

    # Where the game's files are.
    DATABASE_PATH=#{get.("DATABASE_PATH", "pythelix.db")}
    WORLDLETS_PATH=#{get.("WORLDLETS_PATH", "worldlets")}
    SCENARIOS_PATH=#{get.("SCENARIOS_PATH", "scenarios")}
    TASKS_PATH=#{get.("TASKS_PATH", "tasks")}

    # Ports. Players connect with a MUD client on TELNET_PORT; the web server
    # listens on WEB_PORT.
    TELNET_PORT=#{get.("TELNET_PORT", "4000")}
    WEB_PORT=#{get.("WEB_PORT", "8000")}

    # Encodings. Supported values: #{encodings}.
    #
    # DEFAULT_ENCODING is what a player's client is assumed to use when it
    # connects (a script can change it per client afterwards).
    #
    # WORLDLETS_ENCODING is how a worldlet or scenario file is read when it is
    # not valid UTF-8. A UTF-8 file is always read as UTF-8, whatever this
    # says. Leave it empty to use DEFAULT_ENCODING.
    DEFAULT_ENCODING=#{get.("DEFAULT_ENCODING", "utf-8")}
    WORLDLETS_ENCODING=#{get.("WORLDLETS_ENCODING", "")}

    # Generic entities: the keys of the entities every client, character,
    # menu, command, random-string generator and calendar inherits from.
    # Change them only if your worldlets define these base entities under
    # other keys.
    GENERIC_CLIENT=#{get.("GENERIC_CLIENT", "generic/client")}
    GENERIC_CHARACTER=#{get.("GENERIC_CHARACTER", "generic/character")}
    GENERIC_MENU=#{get.("GENERIC_MENU", "generic/menu")}
    GENERIC_COMMAND=#{get.("GENERIC_COMMAND", "generic/command")}
    GENERIC_RANGEN=#{get.("GENERIC_RANGEN", "generic/rangen")}
    GENERIC_CALENDAR=#{get.("GENERIC_CALENDAR", "generic/calendar")}

    # The secret the web server signs its cookies with. It was generated for
    # this game; keep it private and don't change it without a reason.
    SECRET_KEY_BASE=#{get.("SECRET_KEY_BASE", generate_secret())}
    """
  end

  @doc """
  Look a setting up: the environment first, then the file, then the default.

  `names` lists every environment variable that may carry the setting, so an
  older name (`PYTHELIX_DEFAULT_ENCODING`, `PORT`) keeps working next to the
  one the file uses. The file is only consulted under the first name.
  An empty value, in the environment or in the file, means "not set".
  """
  @spec get(%{binary() => binary()}, [binary()], binary() | nil) :: binary() | nil
  def get(settings, [name | _] = names, default \\ nil) do
    Enum.find_value(names, &present(System.get_env(&1))) ||
      present(Map.get(settings, name)) ||
      default
  end

  defp present(nil), do: nil

  defp present(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  # The file is read before the configured encodings are known, so it gets the
  # same treatment as any file a builder writes: UTF-8 when it is valid, and a
  # best effort for the one Windows editors most often produce otherwise.
  defp decode(text) do
    text = if String.valid?(text), do: text, else: Encoding.decode(text, "cp1252")
    strip_bom(text)
  end

  defp strip_bom("﻿" <> rest), do: rest
  defp strip_bom(text), do: text

  defp generate_secret do
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end
end
