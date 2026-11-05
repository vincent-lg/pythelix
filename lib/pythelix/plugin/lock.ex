defmodule Pythelix.Plugin.Lock do
  @moduledoc """
  `plugins.lock`: what was installed, and what it looked like at the time.

  A JSON file at the game's root, written by the plugin commands only and meant
  to be committed with the game. For each plugin, it records the version, where
  it came from, the hash of the downloaded archive, and the hashes of what was
  extracted (see `Pythelix.Plugin.TreeHash`).

  A plugin in `plugins/` with no entry here is a local plugin: it is loaded, but
  never hash-checked and never updated.
  """

  alias Pythelix.Paths

  @file_name "plugins.lock"
  @format 1

  @type entry :: %{
          required(:version) => binary(),
          required(:source) => binary(),
          required(:archive_hash) => binary(),
          required(:tree_hash) => binary(),
          required(:files) => %{binary() => binary()}
        }

  @doc """
  Where the lock file is.
  """
  @spec path() :: binary()
  def path, do: Path.join(Paths.base_path(), @file_name)

  @doc """
  Read the lock file. No file means nothing is locked.
  """
  @spec read() :: {:ok, %{binary() => entry()}} | {:error, binary()}
  def read do
    case File.read(path()) do
      {:ok, text} -> decode(text)
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, "Cannot read #{path()}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Record a plugin, replacing what was known about it.
  """
  @spec put(binary(), entry()) :: :ok | {:error, binary()}
  def put(key, entry) do
    with {:ok, entries} <- read() do
      entries |> Map.put(key, entry) |> write()
    end
  end

  @doc """
  Forget a plugin. Without any plugin left, the file goes away with it.
  """
  @spec delete(binary()) :: :ok | {:error, binary()}
  def delete(key) do
    with {:ok, entries} <- read() do
      entries |> Map.delete(key) |> write()
    end
  end

  defp write(entries) when entries == %{} do
    File.rm(path())

    :ok
  end

  defp write(entries) do
    File.write!(path(), encode(entries) <> "\n")

    :ok
  end

  # Sorted, so that the file changes as little as possible in a diff.
  defp encode(entries) do
    plugins =
      entries
      |> Enum.sort()
      |> Enum.map(fn {key, entry} -> {key, encode_entry(entry)} end)
      |> Jason.OrderedObject.new()

    [format: @format, plugins: plugins]
    |> Jason.OrderedObject.new()
    |> Jason.encode!(pretty: true)
  end

  defp encode_entry(entry) do
    Jason.OrderedObject.new(
      version: entry.version,
      source: entry.source,
      archive_hash: entry.archive_hash,
      tree_hash: entry.tree_hash,
      files: entry.files |> Enum.sort() |> Jason.OrderedObject.new()
    )
  end

  defp decode(text) do
    with {:ok, %{"plugins" => plugins}} when is_map(plugins) <- Jason.decode(text),
         true <- Enum.all?(Map.values(plugins), &valid_entry?/1) do
      {:ok, Map.new(plugins, fn {key, entry} -> {key, decode_entry(entry)} end)}
    else
      _unreadable ->
        {:error, "#{path()} is not a lock file Pythelix can read. Was it edited by hand?"}
    end
  end

  defp valid_entry?(%{"version" => version, "tree_hash" => tree, "files" => files})
       when is_binary(version) and is_binary(tree) and is_map(files),
       do: true

  defp valid_entry?(_entry), do: false

  defp decode_entry(entry) do
    %{
      version: entry["version"],
      source: Map.get(entry, "source", ""),
      archive_hash: Map.get(entry, "archive_hash", ""),
      tree_hash: entry["tree_hash"],
      files: entry["files"]
    }
  end
end
