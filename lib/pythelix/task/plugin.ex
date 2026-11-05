defmodule Pythelix.Task.Plugin do
  @moduledoc """
  The plugin commands, behind `mix pythelix.plugin` and `bin/plugin`.

  None of them need a running server. Those that change plugins only touch
  files, and say so: the game picks the change up the next time it applies.
  """

  alias Pythelix.Paths
  alias Pythelix.Plugin
  alias Pythelix.Plugin.{Eject, Integrity, Lock, Manifest}
  alias Pythelix.Task.Scenario

  @usage """
  Usage: plugin <command>

    list                       the plugins installed, and whether they were modified
    verify [key]               check installed plugins against the lock file
    remove <key> [-f]          delete a plugin (its data stays in the database)
    eject <key>                make a plugin part of the game's own worldlets
    scenario <key>             play a plugin's scenarios, in isolation
  """

  @apply_hint "Run `bin/apply` or restart the server to apply the change."

  @doc """
  Run a plugin command. Returns `:ok` or `:error`, leaving the caller to decide
  what to do about it.
  """
  @spec run(binary() | [binary()]) :: :ok | :error
  def run(args) when is_binary(args), do: run(OptionParser.split(args))

  def run(args) do
    {opts, words, invalid} =
      OptionParser.parse(args, strict: [force: :boolean], aliases: [f: :force])

    if invalid == [] do
      command(words, opts)
    else
      usage()
    end
  end

  @doc """
  Run a plugin command and stop the VM with a status saying whether it worked.
  This is what a release's `bin/plugin` calls.
  """
  @spec main(binary() | [binary()]) :: no_return()
  def main(args) do
    Application.load(:pythelix)

    case run(args) do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
  end

  defp command(["list"], _opts), do: list()
  defp command(["verify"], _opts), do: verify(:all)
  defp command(["verify", key], _opts), do: verify(key)
  defp command(["remove", key], opts), do: remove(key, opts)
  defp command(["eject", key], _opts), do: eject(key)
  defp command(["scenario", key], _opts), do: scenario(key)
  defp command(_words, _opts), do: usage()

  defp usage do
    IO.puts(@usage)

    :error
  end

  # list

  defp list do
    with_lock(fn entries ->
      case Plugin.directories() do
        [] -> IO.puts("No plugin is installed.")
        directories -> Enum.each(directories, &IO.puts(list_line(&1, entries)))
      end

      missing = Map.keys(entries) -- Enum.map(Plugin.directories(), &Path.basename/1)
      Enum.each(missing, &IO.puts("#{&1}: in the lock file, but its directory is gone"))

      :ok
    end)
  end

  defp list_line(directory, entries) do
    key = Path.basename(directory)

    case Manifest.read(directory) do
      {:ok, manifest} ->
        "#{key} #{manifest.version}: #{describe_status(Integrity.status(key, entries[key]))}"

      {:error, reason} ->
        "#{key}: cannot be read (#{reason})"
    end
  end

  defp describe_status(:local), do: "local"
  defp describe_status(:intact), do: "installed"
  defp describe_status(:missing), do: "missing"
  defp describe_status({:modified, _changes}), do: "installed, MODIFIED"

  # verify

  defp verify(which) do
    with_lock(fn entries ->
      keys = if which == :all, do: Enum.sort(Map.keys(entries)), else: [which]

      case keys do
        [] ->
          IO.puts("No plugin is locked, so there's nothing to verify.")

          :ok

        keys ->
          results = Enum.map(keys, &verify_one(&1, entries[&1]))

          (Enum.all?(results, &(&1 == :ok)) && :ok) || :error
      end
    end)
  end

  defp verify_one(key, entry) do
    case {Integrity.status(key, entry), File.dir?(Plugin.path(key))} do
      {:local, false} ->
        fail("#{key}: no such plugin.")

      {:local, true} ->
        IO.puts("#{key}: local, not checked.")

        :ok

      {:intact, _} ->
        IO.puts("#{key}: as installed.")

        :ok

      {:missing, _} ->
        fail("#{key}: in the lock file, but its directory is gone.")

      {{:modified, changes}, _} ->
        fail("#{key}: MODIFIED\n#{Integrity.describe(changes)}")
    end
  end

  # remove

  defp remove(key, opts) do
    with_installed(key, fn entries ->
      case {dependents(key), removal_risk(key, entries[key])} do
        {[_ | _] = dependents, _risk} ->
          fail("Cannot remove #{key}: #{Enum.join(dependents, ", ")} depend on it.")

        {[], risk} when risk != nil and opts != [force: true] ->
          fail("#{risk} Add -f to remove it anyway.")

        {[], _risk} ->
          File.rm_rf!(Plugin.path(key))

          with :ok <- forget(key) do
            IO.puts("Removed #{key}. Its entities stay in the database until you clean them up.")
            IO.puts(@apply_hint)

            :ok
          end
      end
    end)
  end

  # Removing what can't be downloaded again deserves a second thought.
  defp removal_risk(key, nil) do
    "#{key} is a local plugin: there is no other copy of it to install again."
  end

  defp removal_risk(key, entry) do
    case Integrity.status(key, entry) do
      {:modified, changes} ->
        "#{key} was modified, and these edits would be lost:\n#{Integrity.describe(changes)}\n"

      _status ->
        nil
    end
  end

  # eject

  defp eject(key) do
    with_installed(key, fn _entries ->
      case dependents(key) do
        [] ->
          case Eject.run(key) do
            {:ok, moved} ->
              with :ok <- forget(key) do
                Enum.each(moved, &IO.puts("  #{Paths.display(&1)}"))
                IO.puts("#{key} is now part of the game. It won't get updates any more.")
                IO.puts(@apply_hint)

                :ok
              end

            {:error, reason} ->
              fail(reason)
          end

        dependents ->
          fail("Cannot eject #{key}: #{Enum.join(dependents, ", ")} depend on it.")
      end
    end)
  end

  # scenario

  defp scenario(key) do
    case Plugin.manifest(key) do
      {:ok, _manifest} ->
        Scenario.prepare()
        Scenario.run_plugin(key)

      {:error, reason} ->
        fail(reason)
    end
  end

  # Helpers

  defp with_lock(fun) do
    case Lock.read() do
      {:ok, entries} -> fun.(entries)
      {:error, reason} -> fail(reason)
    end
  end

  # A key names a directory that may be deleted: never let it wander out of
  # `plugins/`.
  defp with_installed(key, fun) do
    cond do
      not Plugin.valid_key?(key) -> fail("#{inspect(key)} is not a plugin key.")
      not File.dir?(Plugin.path(key)) -> fail("There is no plugin called #{key}.")
      true -> with_lock(fun)
    end
  end

  defp forget(key) do
    case Lock.delete(key) do
      :ok -> :ok
      {:error, reason} -> fail(reason)
    end
  end

  # Which other plugins need this one. A plugin that can't be read can't be
  # asked, and is reported when the world loads.
  defp dependents(key) do
    Plugin.directories()
    |> Enum.flat_map(fn directory ->
      case Manifest.read(directory) do
        {:ok, manifest} -> [manifest]
        {:error, _} -> []
      end
    end)
    |> Enum.filter(&Map.has_key?(&1.depends, key))
    |> Enum.map(& &1.key)
  end

  defp fail(message) do
    IO.puts(message)

    :error
  end
end
