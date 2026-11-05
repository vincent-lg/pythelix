defmodule Pythelix.Plugin.Archive do
  @moduledoc """
  A plugin as one file, the way the registry publishes it.

  An archive is a gzipped tar with the plugin's files at its root: `plugin.txt`,
  `worldlets/...` and so on. Nothing is trusted when reading one: its contents are
  listed and checked before anything is extracted, and absolute paths, `..`, links
  and anything other than `.txt` and `.md` are refused.
  """

  alias Pythelix.Plugin.TreeHash

  # A plugin is a few kilobytes of text. This only stops an archive from filling
  # the disk.
  @max_size 50 * 1024 * 1024

  @doc """
  Build the archive of a plugin's directory.

  Files that a plugin may not contain are an error, not something to leave out
  silently: the author should know about them.
  """
  @spec build(binary(), binary()) :: :ok | {:error, binary()}
  def build(directory, output) do
    files = TreeHash.relative_files(directory)

    case Enum.reject(files, &TreeHash.allowed?/1) do
      [] ->
        entries =
          Enum.map(files, fn path ->
            {String.to_charlist(path), File.read!(Path.join(directory, path))}
          end)

        File.mkdir_p!(Path.dirname(output))

        case :erl_tar.create(String.to_charlist(output), entries, [:compressed]) do
          :ok -> :ok
          {:error, reason} -> {:error, "Cannot write #{output}: #{inspect(reason)}"}
        end

      refused ->
        {:error,
         "A plugin can only hold #{allowed()} files, and has: #{Enum.join(refused, ", ")}"}
    end
  end

  @doc """
  Extract an archive into a directory, after checking everything in it.
  """
  @spec extract(binary(), binary()) :: :ok | {:error, binary()}
  def extract(archive, destination) do
    with {:ok, table} <- table(archive),
         :ok <- check(table) do
      File.mkdir_p!(destination)

      case :erl_tar.extract(String.to_charlist(archive), [
             :compressed,
             {:cwd, String.to_charlist(destination)}
           ]) do
        :ok -> :ok
        {:error, reason} -> {:error, "Cannot extract the archive: #{inspect(reason)}"}
      end
    end
  end

  defp table(archive) do
    case :erl_tar.table(String.to_charlist(archive), [:compressed, :verbose]) do
      {:ok, table} -> {:ok, table}
      {:error, reason} -> {:error, "This archive cannot be read: #{inspect(reason)}"}
    end
  end

  defp check(table) do
    total = table |> Enum.map(&elem(&1, 2)) |> Enum.sum()

    if total > @max_size do
      {:error, "This archive is unreasonably large (#{total} bytes)."}
    else
      case Enum.flat_map(table, &refusal/1) do
        [] -> :ok
        reasons -> {:error, "This archive was refused:\n" <> Enum.join(reasons, "\n")}
      end
    end
  end

  defp refusal(entry) do
    name = entry |> elem(0) |> to_string()

    cond do
      unsafe?(name) -> ["  #{name}: leaves the plugin's directory"]
      elem(entry, 1) == :directory -> []
      elem(entry, 1) != :regular -> ["  #{name}: is not a regular file"]
      not TreeHash.allowed?(name) -> ["  #{name}: only #{allowed()} files are allowed"]
      true -> []
    end
  end

  # A backslash and a drive letter mean nothing to tar, and everything to Windows.
  defp unsafe?(name) do
    String.contains?(name, "\\") or
      String.starts_with?(name, "/") or
      name =~ ~r/^[A-Za-z]:/ or
      ".." in String.split(name, "/")
  end

  defp allowed, do: Enum.join(TreeHash.extensions(), " and ")
end
