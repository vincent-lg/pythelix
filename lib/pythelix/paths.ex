defmodule Pythelix.Paths do
  @moduledoc """
  Make a path safe to glob.

  On Windows a path arrives with backslashes — from `RELEASE_ROOT`, from the
  command line, from anything the user typed. `File.exists?/1` and `File.dir?/1`
  accept those quite happily, which is what makes the problem easy to miss:
  the checks pass and only the glob fails.

  `Path.wildcard/1` treats a backslash as an *escape character* in the pattern,
  so a perfectly good directory silently matches nothing:

      Path.wildcard("C:\\\\game\\\\scenarios/**/*.txt")   #=> []
      Path.wildcard("C:/game/scenarios/**/*.txt")     #=> [...]

  The result is a "nothing found here" message naming a directory that plainly
  exists. Normalise before globbing.
  """

  @doc """
  Turn every backslash in a path into a forward slash.

  Windows accepts forward slashes everywhere, so this is safe to apply to any
  path, on any platform.
  """
  @spec normalize(binary()) :: binary()
  def normalize(path) when is_binary(path), do: String.replace(path, "\\", "/")

  def normalize(path), do: path

  @doc """
  Work out what a builder meant by a relative path.

  `worldlets/farm` or `scenarios/quests` means "in my game", not "relative to
  wherever this command was launched from". That distinction is invisible until
  someone runs `bin/scenario` from inside `bin`, where the same path suddenly
  resolves nowhere.

  So a relative path is tried as given first — someone standing in their game
  directory should have their shell's tab-completion work — and then against
  the game's root (`PYTHELIX_DIR`, `RELEASE_ROOT`, or the working directory,
  whichever `:base_path` was resolved to). An absolute path is returned
  untouched, and a path that matches nothing is returned as given, so the
  caller reports what the user actually typed.
  """
  @spec resolve(binary()) :: binary()
  def resolve(path) when is_binary(path) do
    Enum.find(candidates(path), path, &File.exists?/1)
  end

  def resolve(path), do: path

  @doc """
  Every place a relative path might mean, in the order they are tried.
  """
  @spec candidates(binary()) :: [binary()]
  def candidates(path) do
    if Path.type(path) == :absolute do
      [path]
    else
      [path, Path.join(base_path(), path)]
    end
  end

  @doc """
  The game's root directory.
  """
  @spec base_path() :: binary()
  def base_path, do: Application.get_env(:pythelix, :base_path) || File.cwd!()
end
