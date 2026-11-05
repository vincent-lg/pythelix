defmodule Pythelix.Plugin.Package do
  @moduledoc """
  Validate a plugin and build its archive, the way the registry's CI does.

  CI computes the hashes and checks the versions, so authors never write either
  by hand. The same code runs for an author who wants to check before submitting.
  """

  alias Pythelix.Plugin
  alias Pythelix.Plugin.{Archive, Manifest, Registry, Requirement, TreeHash}
  alias Pythelix.World.Check

  @readme "docs/README.md"

  @type built :: %{
          manifest: Manifest.t(),
          archive: binary(),
          sha256: binary(),
          tree_hash: binary()
        }

  @doc """
  Check what can be checked without playing anything.

  Scenarios are played by the caller, since that requires starting the game.
  """
  @spec validate(binary()) :: {:ok, Manifest.t()} | {:error, binary()}
  def validate(key) do
    with {:ok, manifest} <- Plugin.manifest(key),
         :ok <- check_files(manifest),
         :ok <- check_readme(manifest),
         :ok <- check_worldlets(key) do
      {:ok, manifest}
    end
  end

  @doc """
  Say whether a version can be published, given the index.

  A new version has to be greater than the last one. A version already published
  never changes: the same content is reported as `:published`, for CI to skip.
  """
  @spec check_version(Manifest.t(), Registry.index()) :: :new | :published | {:error, binary()}
  def check_version(%Manifest{key: key, version: version} = manifest, index) do
    published = Map.get(index, key, %{})

    case Map.fetch(published, version) do
      {:ok, entry} ->
        if entry["tree_hash"] == TreeHash.compute(manifest.directory).tree do
          :published
        else
          {:error, "#{key} #{version} was already published, and has changed since."}
        end

      :error ->
        case published |> Map.keys() |> Enum.sort(&(Requirement.compare(&1, &2) != :lt)) do
          [latest | _] ->
            if Requirement.compare(version, latest) == :gt do
              :new
            else
              {:error, "#{key} #{version} should be greater than the last version, #{latest}."}
            end

          [] ->
            :new
        end
    end
  end

  @doc """
  Build the archive in a directory.
  """
  @spec build(Manifest.t(), binary()) :: {:ok, built()} | {:error, binary()}
  def build(%Manifest{} = manifest, directory) do
    archive = Path.join(directory, "#{manifest.key}-#{manifest.version}.tar.gz")

    with :ok <- Archive.build(manifest.directory, archive) do
      {:ok,
       %{
         manifest: manifest,
         archive: archive,
         sha256: archive |> File.read!() |> TreeHash.sha256(),
         tree_hash: TreeHash.compute(manifest.directory).tree
       }}
    end
  end

  @doc """
  Add a built archive to an index, as the description of where to download it.
  """
  @spec add_to_index(Registry.index(), binary(), binary()) ::
          {:ok, Registry.index()} | {:error, binary()}
  def add_to_index(index, archive, url) do
    directory =
      Path.join(System.tmp_dir!(), "pythelix-index-#{System.unique_integer([:positive])}")

    try do
      with :ok <- Archive.extract(archive, directory),
           {:ok, manifest} <- Manifest.read(directory, key: false) do
        entry = %{
          "name" => manifest.name,
          "description" => manifest.description,
          "pythelix" => manifest.pythelix,
          "depends" => manifest.depends,
          "url" => url,
          "sha256" => archive |> File.read!() |> TreeHash.sha256(),
          "tree_hash" => TreeHash.compute(directory).tree
        }

        {:ok, put_in(index, [Access.key(manifest.key, %{}), manifest.version], entry)}
      end
    after
      File.rm_rf(directory)
    end
  end

  defp check_files(%Manifest{directory: directory}) do
    case directory |> TreeHash.relative_files() |> Enum.reject(&TreeHash.allowed?/1) do
      [] ->
        :ok

      refused ->
        {:error,
         "A plugin can only hold .txt and .md files, and has: #{Enum.join(refused, ", ")}"}
    end
  end

  defp check_readme(%Manifest{key: key, directory: directory}) do
    if File.regular?(Path.join(directory, @readme)) do
      :ok
    else
      {:error, "#{key} needs a #{@readme}, saying what it adds and how to extend it."}
    end
  end

  defp check_worldlets(key) do
    case Check.run({:plugin, key}) do
      {:ok, %{diagnostics: []}} ->
        :ok

      {:ok, %{diagnostics: diagnostics}} ->
        {:error, Enum.map_join(diagnostics, "\n\n", &Pythelix.Scripting.Diagnostic.format/1)}

      :nofile ->
        {:error, "#{key} has no worldlets."}
    end
  end
end
