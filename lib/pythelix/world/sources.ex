defmodule Pythelix.World.Sources do
  @moduledoc """
  Say which worldlet files make up a world, and in which order.

  Applying worldlets, checking them and playing scenarios all need the same
  answer, so they all ask here: what they see can never drift apart.

  The world is built from ordered layers, later ones overriding earlier ones.
  All layers are read and merged before any entity is created, so an override
  is resolved before the entity it adjusts exists.
  """

  alias Pythelix.Paths

  @worldlet_pattern "**/*.txt"

  @type source :: :all | binary()

  @doc """
  The worldlet files of a source, in the order they should be merged.

  The source is `:all` for the whole game, or the path of a file or directory.
  Returns `:nofile` when there is nothing at that place.
  """
  @spec files(source()) :: {:ok, [binary()]} | {:error, binary()} | :nofile
  def files(:all) do
    directory = worldlets_directory()

    if File.exists?(directory) do
      {:ok, glob(directory, @worldlet_pattern)}
    else
      :nofile
    end
  end

  def files(path) when is_binary(path) do
    cond do
      not File.exists?(path) -> :nofile
      File.dir?(path) -> {:ok, glob(path, @worldlet_pattern)}
      true -> {:ok, [path]}
    end
  end

  @doc """
  Name a source for a message to the builder.
  """
  @spec label(source() | :static) :: binary()
  def label(:static), do: "static"
  def label(:all), do: worldlets_directory() |> Paths.normalize() |> Paths.display()
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
