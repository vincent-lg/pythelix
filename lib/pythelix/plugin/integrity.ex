defmodule Pythelix.Plugin.Integrity do
  @moduledoc """
  Tell whether installed plugins are still what was installed.

  A plugin edited in place would lose those edits at its next update. That is
  worth saying loudly, but it isn't worth refusing to start a game over a fixed
  typo, so this only reports: at boot and in `check` through `notices/0`, and it
  is the plugin commands that refuse to destroy anything.
  """

  alias Pythelix.Paths
  alias Pythelix.Plugin
  alias Pythelix.Plugin.{Lock, TreeHash}

  @type status ::
          :local
          | :intact
          | :missing
          | {:modified, [{:changed | :added | :removed, binary()}]}

  @doc """
  The state of a plugin, given its lock entry if it has one.
  """
  @spec status(binary(), Lock.entry() | nil) :: status()
  def status(_key, nil), do: :local

  def status(key, entry) do
    directory = Plugin.path(key)

    if File.dir?(directory) do
      found = TreeHash.compute(directory)

      if found.tree == entry.tree_hash do
        :intact
      else
        {:modified, TreeHash.changes(entry.files, found.files)}
      end
    else
      :missing
    end
  end

  @doc """
  The sentences to show a builder about plugins that aren't as installed.
  """
  @spec notices() :: [binary()]
  def notices do
    case Lock.read() do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.flat_map(fn {key, entry} -> notice(key, status(key, entry)) end)

      {:error, reason} ->
        [reason]
    end
  end

  @doc """
  Say what changed in a modified plugin, one line per file.
  """
  @spec describe([{:changed | :added | :removed, binary()}]) :: binary()
  def describe(changes) do
    Enum.map_join(changes, "\n", fn {change, path} -> "  #{change}: #{Paths.display(path)}" end)
  end

  defp notice(_key, status) when status in [:local, :intact], do: []

  defp notice(key, :missing) do
    ["Plugin #{key} is in #{Path.basename(Lock.path())}, but its directory is gone."]
  end

  defp notice(key, {:modified, changes}) do
    [
      """
      Plugin #{key} was modified in place, and these edits would be lost when it is updated:
      #{describe(changes)}
      To change a plugin, override it from your own worldlets (see docs/plugins.md), \
      or take it over with `plugin eject #{key}`.\
      """
    ]
  end
end
