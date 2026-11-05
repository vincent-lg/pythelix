defmodule Pythelix.Plugin do
  @moduledoc """
  Plugins: packages of worldlets someone else wrote, that a game can use.

  A plugin is a directory in `plugins/`, holding a manifest and worldlets:

      plugins/<key>/
        plugin.txt        # the manifest (see `Pythelix.Plugin.Manifest`)
        worldlets/...     # the plugin's worldlets
        scenarios/...     # the plugin's own tests (optional)
        docs/...          # README.md at least

  This module knows which plugins are there and in which order they load:
  dependencies first, alphabetically among independent ones, so that the order
  is stable. Anything wrong with that (a missing dependency, a version that
  doesn't fit, a cycle) is an error, naming every problem at once.
  """

  alias Pythelix.Paths
  alias Pythelix.Plugin.{Manifest, Requirement}

  @doc """
  The directory plugins are installed in.
  """
  @spec directory() :: binary()
  def directory do
    Application.get_env(:pythelix, :plugins_path) || Path.join(Paths.base_path(), "plugins")
  end

  @doc """
  The directory of a plugin, whether it exists or not.
  """
  @spec path(binary()) :: binary()
  def path(key), do: Path.join(directory(), key)

  @doc """
  Whether a string can be a plugin's key, and so the name of a directory.
  """
  @spec valid_key?(term()) :: boolean()
  def valid_key?(key), do: Manifest.valid_key?(key)

  @doc """
  The directories in `plugins/`, sorted. Hidden ones are left out: they are
  where an install prepares its files.
  """
  @spec directories() :: [binary()]
  def directories do
    case File.ls(directory()) do
      {:ok, names} ->
        names
        |> Enum.reject(&String.starts_with?(&1, "."))
        |> Enum.sort()
        |> Enum.map(&Path.join(directory(), &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  end

  @doc """
  Read the manifest of an installed plugin.
  """
  @spec manifest(binary()) :: {:ok, Manifest.t()} | {:error, binary()}
  def manifest(key) do
    if valid_key?(key) and File.dir?(path(key)) do
      Manifest.read(path(key))
    else
      {:error, "There is no plugin called #{inspect(key)} in #{Paths.display(directory())}."}
    end
  end

  @doc """
  Read the manifests of every plugin in `plugins/`, in no particular order.
  """
  @spec manifests() :: {:ok, [Manifest.t()]} | {:error, binary()}
  def manifests do
    results = Enum.map(directories(), &Manifest.read/1)

    case for {:error, reason} <- results, do: reason do
      [] -> {:ok, for({:ok, manifest} <- results, do: manifest)}
      reasons -> {:error, Enum.join(reasons, "\n")}
    end
  end

  @doc """
  Every installed plugin, in the order it should load.
  """
  @spec load_order() :: {:ok, [Manifest.t()]} | {:error, binary()}
  def load_order do
    with {:ok, manifests} <- manifests() do
      sort(manifests)
    end
  end

  @doc """
  A plugin and what it depends on, and nothing else, in the order they should
  load: the world a plugin's own scenarios play in. Other plugins are not even
  read, so that a broken one can't get in the way.
  """
  @spec load_order(binary()) :: {:ok, [Manifest.t()]} | {:error, binary()}
  def load_order(key) do
    with {:ok, manifests} <- closure([key], %{}) do
      sort(Map.values(manifests))
    end
  end

  @doc """
  Sort manifests so that dependencies come first, checking they all fit.
  """
  @spec sort([Manifest.t()]) :: {:ok, [Manifest.t()]} | {:error, binary()}
  def sort(manifests) do
    case Enum.flat_map(manifests, &problems(&1, manifests)) do
      [] -> order(Enum.sort_by(manifests, & &1.key), [])
      problems -> {:error, Enum.join(problems, "\n")}
    end
  end

  @doc """
  The worldlet files of a plugin, manifest first.
  """
  @spec files(Manifest.t()) :: [binary()]
  def files(%Manifest{directory: directory}) do
    directory = Paths.normalize(directory)

    [
      Path.join(directory, Manifest.file_name())
      | Path.wildcard(Path.join(directory, "worldlets/**/*.txt"))
    ]
  end

  # Read a plugin and, in turn, whatever it says it depends on. A dependency
  # that isn't there is left for `sort/1` to report, along with anything else.
  defp closure([], seen), do: {:ok, seen}

  defp closure([key | rest], seen) when is_map_key(seen, key), do: closure(rest, seen)

  defp closure([key | rest], seen) do
    cond do
      File.dir?(path(key)) ->
        with {:ok, manifest} <- Manifest.read(path(key)) do
          closure(Map.keys(manifest.depends) ++ rest, Map.put(seen, key, manifest))
        end

      seen == %{} ->
        manifest(key)

      true ->
        closure(rest, seen)
    end
  end

  defp problems(manifest, manifests) do
    engine_problem(manifest) ++ dependency_problems(manifest, manifests)
  end

  defp engine_problem(%Manifest{key: key, pythelix: requirement}) do
    engine = Requirement.engine_version()

    if Requirement.satisfied?(engine, requirement) do
      []
    else
      ["Plugin #{key} needs Pythelix #{requirement}, and this is Pythelix #{engine}."]
    end
  end

  defp dependency_problems(manifest, manifests) do
    manifest.depends
    |> Enum.sort()
    |> Enum.flat_map(fn {dependency, requirement} ->
      case Enum.find(manifests, &(&1.key == dependency)) do
        nil ->
          [
            "Plugin #{manifest.key} needs the plugin #{dependency} (#{requirement}), " <>
              "which isn't installed."
          ]

        found ->
          if Requirement.satisfied?(found.version, requirement) do
            []
          else
            [
              "Plugin #{manifest.key} needs #{dependency} #{requirement}, " <>
                "and version #{found.version} is installed."
            ]
          end
      end
    end)
  end

  # Take the first plugin whose dependencies have all been placed, again and
  # again. Taking from a sorted list is what keeps independent plugins in
  # alphabetical order.
  defp order([], placed), do: {:ok, Enum.reverse(placed)}

  defp order(remaining, placed) do
    keys = Enum.map(placed, & &1.key)

    case Enum.find(remaining, fn manifest ->
           Enum.all?(Map.keys(manifest.depends), &(&1 in keys))
         end) do
      nil ->
        names = remaining |> Enum.map(& &1.key) |> Enum.join(", ")

        {:error, "These plugins depend on each other in a circle: #{names}."}

      next ->
        order(List.delete(remaining, next), [next | placed])
    end
  end
end
