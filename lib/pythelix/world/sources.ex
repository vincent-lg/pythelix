defmodule Pythelix.World.Sources do
  @moduledoc """
  Say which worldlet files make up a world, and in which order.

  Applying worldlets, checking them and playing scenarios all need the same
  answer, so they all ask here: what they see can never drift apart.

  The world is built from ordered layers, later ones overriding earlier ones:

  1. the engine's built-in entities (added by `Pythelix.World`);
  2. the installed plugins, dependencies first;
  3. the game's own worldlets.

  All layers are read and merged before any entity is created, so an override
  is resolved before the entity it adjusts exists.
  """

  alias Pythelix.{Paths, Plugin}
  alias Pythelix.Plugin.{Integrity, Manifest}

  @worldlet_pattern "**/*.txt"

  @type source :: :all | {:plugin, binary()} | binary()

  @doc """
  The worldlet files of a source, in the order they should be merged.

  The source is one of:

  - `:all`: the whole game, every layer;
  - `{:plugin, key}`: a plugin and its dependencies, without the game's own
    worldlets or any other plugin, which is what a plugin's scenarios play on;
  - the path of a file or a directory. A directory holding a plugin means that
    plugin's worldlets, not everything in it: its scenarios are not worldlets.

  Returns `:nofile` when there is nothing at that place, and an error when the
  plugins can't be loaded together.
  """
  @spec files(source()) :: {:ok, [binary()]} | {:error, binary()} | :nofile
  def files(:all) do
    directory = worldlets_directory()

    with {:ok, plugins} <- Plugin.load_order() do
      if plugins == [] and not File.exists?(directory) do
        :nofile
      else
        {:ok, Enum.flat_map(plugins, &Plugin.files/1) ++ glob(directory, @worldlet_pattern)}
      end
    end
  end

  def files({:plugin, key}) do
    with {:ok, plugins} <- Plugin.load_order(key) do
      {:ok, Enum.flat_map(plugins, &Plugin.files/1)}
    end
  end

  def files(path) when is_binary(path) do
    cond do
      not File.exists?(path) -> :nofile
      Manifest.present?(path) -> plugin_files(path)
      File.dir?(path) -> {:ok, glob(path, @worldlet_pattern)}
      true -> {:ok, [path]}
    end
  end

  defp plugin_files(directory) do
    with {:ok, manifest} <- Manifest.read(directory) do
      {:ok, Plugin.files(manifest)}
    end
  end

  @doc """
  What deserves saying about a source, even though it loads. A plugin's isolated
  world is about the plugin as written, so only the whole game gets this.
  """
  @spec notices(source() | :static) :: [binary()]
  def notices(:all), do: Integrity.notices()
  def notices(_source), do: []

  @doc """
  Name a source for a message to the builder.
  """
  @spec label(source() | :static) :: binary()
  def label(:static), do: "static"
  def label(:all), do: worldlets_directory() |> Paths.normalize() |> Paths.display()
  def label({:plugin, key}), do: "plugin #{key}"
  def label(path) when is_binary(path), do: Paths.display(path)

  defp worldlets_directory do
    Application.get_env(:pythelix, :worldlets_path, Path.join(File.cwd!(), "worldlets"))
  end

  # Windows gives us backslashes, and `Path.wildcard/1` treats a backslash as an
  # escape character, so a real directory silently matches nothing. Normalise
  # before globbing (see `Pythelix.Paths`).
  defp glob(directory, pattern) do
    Path.wildcard("#{Paths.normalize(directory)}/#{pattern}")
  end
end
