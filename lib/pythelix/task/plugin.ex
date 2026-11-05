defmodule Pythelix.Task.Plugin do
  @moduledoc """
  The plugin commands, behind `mix pythelix.plugin` and `bin/plugin`.

  None of them need a running server. Those that change plugins only touch
  files, and say so: the game picks the change up the next time it applies.
  """

  alias Pythelix.Paths
  alias Pythelix.Plugin
  alias Pythelix.Plugin.{Eject, Installer, Integrity, Lock, Manifest, Package, Registry}
  alias Pythelix.Plugin.Requirement
  alias Pythelix.Task.Scenario

  @usage """
  Usage: plugin <command>

    list                       online, installed and local plugins
    verify [key]               check installed plugins against the lock file
    install <key>[@version]    download a plugin and what it depends on
    update [key] [-f]          update plugins, refusing to lose edits without -f
    remove <key> [-f]          delete a plugin (its data stays in the database)
    eject <key>                make a plugin part of the game's own worldlets
    package <key>              validate a plugin and build its archive
    scenario <key>             play a plugin's scenarios, in isolation

  For the registry's CI:

    package <key> --index <file> --output <directory> [--no-scenarios]
    index <file> <archive> <url>   add a built archive to an index
  """

  @switches [force: :boolean, index: :string, output: :string, scenarios: :boolean]

  @apply_hint "Run `bin/apply` or restart the server to apply the change."

  @doc """
  Run a plugin command. Returns `:ok` or `:error`, leaving the caller to decide
  what to do about it.
  """
  @spec run(binary() | [binary()]) :: :ok | :error
  def run(args) when is_binary(args), do: run(OptionParser.split(args))

  def run(args) do
    {opts, words, invalid} =
      OptionParser.parse(args, strict: @switches, aliases: [f: :force])

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
  defp command(["install", spec], opts), do: install(spec, opts)
  defp command(["update"], opts), do: update(:all, opts)
  defp command(["update", key], opts), do: update(key, opts)
  defp command(["remove", key], opts), do: remove(key, opts)
  defp command(["package", key], opts), do: package(key, opts)
  defp command(["index", file, archive, url], _opts), do: index(file, archive, url)
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
      directories = Plugin.directories()

      case directories do
        [] -> IO.puts("No plugin is installed.")
        directories -> Enum.each(directories, &IO.puts(list_line(&1, entries)))
      end

      missing = Map.keys(entries) -- Enum.map(directories, &Path.basename/1)
      Enum.each(missing, &IO.puts("#{&1}: in the lock file, but its directory is gone"))

      list_online(Enum.map(directories, &Path.basename/1))

      :ok
    end)
  end

  # Being offline shouldn't stop anyone from seeing what's installed.
  defp list_online(installed) do
    case Registry.fetch_index() do
      {:ok, index} ->
        index
        |> Map.drop(installed)
        |> Enum.sort()
        |> Enum.each(fn {key, versions} -> IO.puts(online_line(key, versions)) end)

      {:error, reason} ->
        IO.puts("The registry can't be listed: #{reason}")
    end
  end

  defp online_line(key, versions) do
    latest = versions |> Map.keys() |> Enum.sort(&(Requirement.compare(&1, &2) != :lt)) |> hd()

    case versions[latest]["description"] do
      nil -> "#{key} #{latest}: available"
      description -> "#{key} #{latest}: available - #{description}"
    end
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
    opts = Map.new(opts)

    with_installed(key, fn entries ->
      case {dependents(key), removal_risk(key, entries[key])} do
        {[_ | _] = dependents, _risk} ->
          fail("Cannot remove #{key}: #{Enum.join(dependents, ", ")} depend on it.")

        {[], risk} when risk != nil and not is_map_key(opts, :force) ->
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

  # install

  defp install(spec, opts) do
    {key, version} =
      case String.split(spec, "@", parts: 2) do
        [key, version] -> {key, version}
        [key] -> {key, nil}
      end

    case Installer.install(key, version, opts) do
      {:ok, outcomes} ->
        report_changes(outcomes)

      {:error, reason} ->
        fail(reason)
    end
  end

  # update

  defp update(which, opts) do
    case Installer.update(which, opts) do
      {:ok, [], []} ->
        IO.puts("No plugin is locked, so there's nothing to update.")

        :ok

      {:ok, [], current} ->
        Enum.each(current, &IO.puts("#{&1} is already up to date."))

        :ok

      {:ok, outcomes, current} ->
        Enum.each(current, &IO.puts("#{&1} is already up to date."))
        report_changes(outcomes)

      {:error, reason} ->
        fail(reason)
    end
  end

  defp report_changes(outcomes) do
    Enum.each(outcomes, fn {key, version} -> IO.puts("Installed #{key} #{version}.") end)
    IO.puts(@apply_hint)

    :ok
  end

  # package

  defp package(key, opts) do
    with {:ok, manifest} <- Package.validate(key),
         {:ok, status} <- check_published(manifest, opts),
         :ok <- play_scenarios(key, status, opts) do
      build_package(manifest, status, opts)
    else
      {:error, reason} -> fail(reason)
      :error -> :error
    end
  end

  defp check_published(manifest, opts) do
    case opts[:index] do
      nil ->
        {:ok, :new}

      file ->
        with {:ok, index} <- read_index(file) do
          case Package.check_version(manifest, index) do
            {:error, _} = error -> error
            status -> {:ok, status}
          end
        end
    end
  end

  defp play_scenarios(_key, :published, _opts), do: :ok

  defp play_scenarios(key, _status, opts) do
    if Keyword.get(opts, :scenarios, true) do
      Scenario.prepare()
      Scenario.run_plugin(key)
    else
      :ok
    end
  end

  defp build_package(manifest, :published, _opts) do
    IO.puts("#{manifest.key} #{manifest.version} is already published.")

    :ok
  end

  defp build_package(manifest, :new, opts) do
    case Package.build(manifest, Keyword.get(opts, :output, Paths.base_path())) do
      {:ok, built} ->
        IO.puts("Built #{Paths.display(built.archive)}")
        IO.puts("sha256: #{built.sha256}")

        :ok

      {:error, reason} ->
        fail(reason)
    end
  end

  # index

  defp index(file, archive, url) do
    with {:ok, index} <- read_index(file),
         {:ok, index} <- Package.add_to_index(index, archive, url) do
      File.write!(file, Registry.encode_index(index))
      IO.puts("Added #{Path.basename(archive)} to #{file}.")

      :ok
    else
      {:error, reason} -> fail(reason)
    end
  end

  # An index that doesn't exist yet is the empty one: the first plugin creates it.
  defp read_index(file) do
    case File.read(file) do
      {:ok, text} -> Registry.decode_index(text)
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, "Cannot read #{file}: #{:file.format_error(reason)}"}
    end
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
