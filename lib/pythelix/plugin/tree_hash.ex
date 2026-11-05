defmodule Pythelix.Plugin.TreeHash do
  @moduledoc """
  A fingerprint of a plugin's directory, to tell whether it was edited in place.

  It is computed over a canonical form: relative paths with forward slashes,
  sorted, and file contents with line endings normalised to LF. Without that last
  step, git's `autocrlf` on Windows would make every plugin look modified.

  Only the files a plugin may contain count (`.txt` and `.md`), so what an editor
  or a file manager leaves behind doesn't make a plugin look modified either.
  """

  @extensions [".txt", ".md"]

  @type t :: %{tree: binary(), files: %{binary() => binary()}}

  @doc """
  The extensions a plugin's files may have.
  """
  @spec extensions() :: [binary()]
  def extensions, do: @extensions

  @doc """
  Whether a plugin may contain a file of this name.
  """
  @spec allowed?(binary()) :: boolean()
  def allowed?(path), do: String.downcase(Path.extname(path)) in @extensions

  @doc """
  Hash a plugin's directory.

  Returns the tree hash, along with the hash of each file: the tree hash says
  whether anything changed, and the others say what.
  """
  @spec compute(binary()) :: t()
  def compute(directory) do
    files =
      directory
      |> relative_files()
      |> Enum.filter(&allowed?/1)
      |> Map.new(fn path -> {path, hash_file(Path.join(directory, path))} end)

    %{tree: tree(files), files: files}
  end

  @doc """
  Every file under a directory, as sorted relative paths with forward slashes.
  """
  @spec relative_files(binary()) :: [binary()]
  def relative_files(directory) do
    root = Pythelix.Paths.normalize(directory)

    "#{root}/**/*"
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.sort()
  end

  @doc """
  What differs between the file hashes recorded and the ones found.
  """
  @spec changes(map(), map()) :: [{:changed | :added | :removed, binary()}]
  def changes(recorded, found) do
    paths = (Map.keys(recorded) ++ Map.keys(found)) |> Enum.uniq() |> Enum.sort()

    Enum.flat_map(paths, fn path ->
      case {Map.fetch(recorded, path), Map.fetch(found, path)} do
        {{:ok, same}, {:ok, same}} -> []
        {{:ok, _}, {:ok, _}} -> [{:changed, path}]
        {{:ok, _}, :error} -> [{:removed, path}]
        {:error, {:ok, _}} -> [{:added, path}]
      end
    end)
  end

  @doc """
  Hash some bytes, the way every hash in plugins is written.
  """
  @spec sha256(iodata()) :: binary()
  def sha256(data), do: :sha256 |> :crypto.hash(data) |> Base.encode16(case: :lower)

  defp hash_file(path) do
    path
    |> File.read!()
    |> normalise_line_endings()
    |> sha256()
  end

  defp normalise_line_endings(text) do
    text
    |> :binary.replace("\r\n", "\n", [:global])
    |> :binary.replace("\r", "\n", [:global])
  end

  defp tree(files) do
    files
    |> Enum.sort()
    |> Enum.map(fn {path, hash} -> "#{hash}  #{path}\n" end)
    |> sha256()
  end
end
