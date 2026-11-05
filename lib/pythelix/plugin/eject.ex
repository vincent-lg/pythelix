defmodule Pythelix.Plugin.Eject do
  @moduledoc """
  Turn a plugin into part of the game, for someone who really wants to take it
  over.

  Moving the whole directory to `worldlets/<key>` wouldn't do: everything in
  there is read as a worldlet, and a plugin's scenarios aren't worldlets. So each
  part goes where the game keeps such things:

      plugins/<key>/worldlets/...           -> worldlets/<key>/...
      plugins/<key>/scenarios/...           -> scenarios/<key>/...
      plugins/<key>/scenarios/fixtures/...  -> scenarios/fixtures/<key>/...
      plugins/<key>/docs/...                -> docs/plugins/<key>/...

  The manifest goes away, since this isn't a plugin any more. Scenarios keep
  finding their fixtures: their `apply` lines are rewritten for the new place.
  """

  alias Pythelix.Paths
  alias Pythelix.Plugin
  alias Pythelix.Plugin.TreeHash

  @doc """
  Move a plugin's parts into the game. Returns the places they went.

  Nothing is moved if any of those places is already taken.
  """
  @spec run(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def run(key) do
    directory = Plugin.path(key)

    moves =
      key
      |> destinations()
      |> Enum.map(fn {from, to} -> {Path.join(directory, from), to} end)
      |> Enum.filter(fn {from, _to} -> File.dir?(from) end)

    case Enum.find(moves, fn {_from, to} -> File.exists?(to) end) do
      {_from, to} ->
        {:error, "Cannot eject #{key}: #{Paths.display(to)} already exists."}

      nil ->
        rewrite_scenarios(directory, key)
        # Fixtures live inside the scenarios directory, so they have to leave first.
        Enum.each(moves, &move/1)
        File.rm_rf!(directory)

        {:ok, Enum.map(moves, fn {_from, to} -> to end)}
    end
  end

  defp destinations(key) do
    [
      {"scenarios/fixtures", Path.join([scenarios_directory(), "fixtures", key])},
      {"worldlets", Path.join(worldlets_directory(), key)},
      {"scenarios", Path.join(scenarios_directory(), key)},
      {"docs", Path.join([Paths.base_path(), "docs", "plugins", key])}
    ]
  end

  defp move({from, to}) do
    File.mkdir_p!(Path.dirname(to))
    File.rename!(from, to)
  end

  # `apply goblins.txt` is looked for in `scenarios/fixtures`, and the fixture is
  # about to be in `scenarios/fixtures/<key>`.
  defp rewrite_scenarios(directory, key) do
    scenarios = Path.join(directory, "scenarios")
    fixtures = Path.join(scenarios, "fixtures")

    scenarios
    |> TreeHash.relative_files()
    |> Enum.reject(&String.starts_with?(&1, "fixtures/"))
    |> Enum.filter(&(Path.extname(&1) == ".txt"))
    |> Enum.each(fn file ->
      path = Path.join(scenarios, file)
      text = File.read!(path)
      rewritten = rewrite_applies(text, key, fixtures)

      if rewritten != text, do: File.write!(path, rewritten)
    end)
  end

  defp rewrite_applies(text, key, fixtures) do
    Regex.replace(~r/^(\s*apply\s+)(\S+)/m, text, fn whole, start, fixture ->
      if File.exists?(Path.join(fixtures, fixture)) do
        "#{start}#{key}/#{fixture}"
      else
        whole
      end
    end)
  end

  defp worldlets_directory do
    Application.get_env(:pythelix, :worldlets_path, Path.join(Paths.base_path(), "worldlets"))
  end

  defp scenarios_directory do
    Application.get_env(:pythelix, :scenarios_path, Path.join(Paths.base_path(), "scenarios"))
  end
end
