defmodule Pythelix.Plugin.Installer do
  @moduledoc """
  Download, check and put plugins in place.

  Everything is prepared in a hidden directory inside `plugins/`, and only moved
  into place once every plugin of the operation has been downloaded and checked.
  A failure along the way therefore leaves the game exactly as it was.

  This only touches files. The game picks the change up the next time it applies.
  """

  alias Pythelix.Plugin

  alias Pythelix.Plugin.{
    Archive,
    Integrity,
    Lock,
    Manifest,
    Registry,
    Requirement,
    Resolver,
    TreeHash
  }

  @type outcome :: {binary(), binary()}

  @doc """
  Install a plugin and whatever it depends on.

  A plugin already there is left alone, unless `force: true` is given to replace
  a local one with the published one, which lets it receive updates from then on.
  """
  @spec install(binary(), binary() | nil, keyword()) ::
          {:ok, [outcome()]} | {:error, binary()}
  def install(key, version, opts \\ []) do
    requirement = version && "==#{version}"

    with :ok <- check_key(key),
         {:ok, entries} <- Lock.read(),
         :ok <- check_not_installed(key, entries, opts),
         {:ok, index} <- Registry.fetch_index(),
         {:ok, installed} <- installed_versions(key),
         {:ok, choices} <- Resolver.plan([{key, requirement}], index, installed) do
      put_in_place(choices)
    end
  end

  @doc """
  Update plugins to their most recent version.

  `:all` means every plugin in the lock file: local ones are never updated. A
  plugin modified in place is refused unless `force: true` is given, since the
  edits would be lost.
  """
  @spec update(binary() | :all, keyword()) ::
          {:ok, [outcome()], [binary()]} | {:error, binary()}
  def update(which, opts \\ []) do
    with {:ok, entries} <- Lock.read(),
         {:ok, keys} <- keys_to_update(which, entries),
         :ok <- check_not_modified(keys, entries, opts),
         {:ok, index} <- Registry.fetch_index(),
         {:ok, installed} <- installed_versions(nil),
         requests = Enum.map(keys, &{&1, nil}),
         {:ok, choices} <- Resolver.plan(requests, index, installed, constraints(keys)) do
      {current, changing} = split_current(choices, installed)

      with {:ok, outcomes} <- put_in_place(changing) do
        {:ok, outcomes, Enum.map(current, fn {choice_key, _, _} -> choice_key end)}
      end
    end
  end

  defp check_key(key) do
    if Plugin.valid_key?(key), do: :ok, else: {:error, "#{inspect(key)} is not a plugin key."}
  end

  defp check_not_installed(key, entries, opts) do
    cond do
      Map.has_key?(entries, key) ->
        {:error, "#{key} is already installed. To change its version, update it."}

      File.exists?(Plugin.path(key)) and not Keyword.get(opts, :force, false) ->
        {:error,
         "#{key} is a local plugin in #{Pythelix.Paths.display(Plugin.path(key))}. " <>
           "Add -f to replace it with the published one."}

      true ->
        :ok
    end
  end

  # What's there and isn't about to be replaced.
  defp installed_versions(replaced) do
    with {:ok, manifests} <- readable_manifests() do
      {:ok,
       manifests
       |> Enum.reject(&(&1.key == replaced))
       |> Map.new(&{&1.key, &1.version})}
    end
  end

  defp readable_manifests do
    {:ok,
     Plugin.directories()
     |> Enum.map(&Manifest.read/1)
     |> Enum.flat_map(fn
       {:ok, manifest} -> [manifest]
       {:error, _} -> []
     end)}
  end

  defp keys_to_update(:all, entries), do: {:ok, entries |> Map.keys() |> Enum.sort()}

  defp keys_to_update(key, entries) do
    cond do
      Map.has_key?(entries, key) ->
        {:ok, [key]}

      Plugin.valid_key?(key) and File.dir?(Plugin.path(key)) ->
        {:error, "#{key} is a local plugin, so it's never updated."}

      true ->
        {:error, "There is no plugin called #{inspect(key)} to update."}
    end
  end

  defp check_not_modified(keys, entries, opts) do
    modified =
      Enum.flat_map(keys, fn key ->
        case Integrity.status(key, entries[key]) do
          {:modified, changes} -> [{key, changes}]
          _status -> []
        end
      end)

    if modified == [] or Keyword.get(opts, :force, false) do
      :ok
    else
      details =
        Enum.map_join(modified, "\n", fn {key, changes} ->
          "#{key} was modified, and these edits would be lost:\n#{Integrity.describe(changes)}"
        end)

      {:error,
       details <>
         "\nOverride what you need from your own worldlets instead (see docs/plugins.md), " <>
         "take the plugin over with `plugin eject`, or add -f to lose the edits."}
    end
  end

  # What the plugins staying as they are expect of those being updated.
  defp constraints(keys) do
    {:ok, manifests} = readable_manifests()

    for manifest <- manifests,
        manifest.key not in keys,
        {dependency, requirement} <- manifest.depends do
      {dependency, requirement, manifest.key}
    end
  end

  defp split_current(choices, installed) do
    Enum.split_with(choices, fn {key, version, _entry} ->
      Map.has_key?(installed, key) and Requirement.compare(installed[key], version) == :eq
    end)
  end

  # Fetch and check everything first, so that nothing has moved if any of it fails.
  defp put_in_place([]), do: {:ok, []}

  defp put_in_place(choices) do
    File.mkdir_p!(Plugin.directory())
    staging = Path.join(Plugin.directory(), ".staging-#{System.unique_integer([:positive])}")

    try do
      with {:ok, prepared} <- prepare_all(choices, staging) do
        Enum.each(prepared, &commit(&1, staging))

        {:ok, Enum.map(prepared, &{&1.key, &1.version})}
      end
    after
      File.rm_rf(staging)
    end
  end

  defp prepare_all(choices, staging) do
    Enum.reduce_while(choices, {:ok, []}, fn choice, {:ok, prepared} ->
      case prepare(choice, staging) do
        {:ok, ready} -> {:cont, {:ok, [ready | prepared]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp prepare({key, version, entry}, staging) do
    url = Map.get(entry, "url", "")
    archive = Path.join(staging, "#{key}.tar.gz")
    directory = Path.join(staging, key)

    with {:ok, body} <- Registry.download(url),
         hash = TreeHash.sha256(body),
         :ok <- check_hash(key, hash, entry),
         :ok <- write_archive(archive, body),
         :ok <- Archive.extract(archive, directory),
         {:ok, manifest} <- Manifest.read(directory, key: key),
         :ok <- check_version(manifest, version),
         found = TreeHash.compute(directory),
         :ok <- check_tree(key, found, entry) do
      {:ok, %{key: key, version: version, source: url, archive_hash: hash, found: found}}
    end
  end

  defp write_archive(archive, body) do
    File.mkdir_p!(Path.dirname(archive))
    File.write!(archive, body)

    :ok
  end

  defp check_hash(key, hash, entry) do
    if hash == entry["sha256"] do
      :ok
    else
      {:error,
       "The archive of #{key} isn't the one the registry describes: " <>
         "expected #{inspect(entry["sha256"])}, got #{hash}. Nothing was installed."}
    end
  end

  defp check_version(%Manifest{version: version}, version), do: :ok

  defp check_version(%Manifest{key: key, version: found}, version) do
    {:error, "The archive of #{key} #{version} says it holds version #{found}."}
  end

  defp check_tree(key, found, entry) do
    case entry["tree_hash"] do
      nil -> :ok
      tree when tree == found.tree -> :ok
      _other -> {:error, "The files of #{key} aren't the ones the registry describes."}
    end
  end

  # Move the old version away first, so that an interrupted update doesn't mix
  # two versions in one directory.
  defp commit(ready, staging) do
    target = Plugin.path(ready.key)
    former = Path.join(staging, "#{ready.key}.former")

    if File.exists?(target), do: File.rename!(target, former)
    File.rename!(Path.join(staging, ready.key), target)

    :ok =
      Lock.put(ready.key, %{
        version: ready.version,
        source: ready.source,
        archive_hash: ready.archive_hash,
        tree_hash: ready.found.tree,
        files: ready.found.files
      })
  end
end
