defmodule Mix.Tasks.Test.Par do
  @shortdoc "Runs the test suite split across parallel OS processes"

  @moduledoc """
  Runs `mix test --partitions N` once per partition, each in its own OS
  process, and waits for all of them.

      mix test.par            # one partition per scheduler, at most 4
      mix test.par 3          # three partitions
      mix test.par 3 --seed 0 # extra arguments are passed to each `mix test`

  Most of the suite is synchronous because entities live in process-global
  caches and the game hub applies database changes from its own process, so
  tests cannot share a VM safely. Separate OS processes side-step that: each
  partition gets its own VM, its own caches, its own telnet port and its own
  SQLite file (the test configuration derives both from `MIX_TEST_PARTITION`).

  Before the partitions start, the project is compiled once for the test
  environment and every partition database is created and migrated, so the
  partitions neither compile concurrently nor race their own migrations.
  """

  use Mix.Task

  @max_default 4

  @impl Mix.Task
  def run(args) do
    {count, rest} = parse_args(args)

    Mix.shell().info("Compiling for the test environment...")
    mix!(["compile"], [{"MIX_ENV", "test"}])

    Mix.shell().info("Preparing #{count} test databases...")

    1..count
    |> Enum.map(fn index ->
      Task.async(fn ->
        mix!(["do", "ecto.create", "--quiet,", "ecto.migrate", "--quiet"], env(index))
      end)
    end)
    |> Task.await_many(:infinity)

    Mix.shell().info("Running #{count} partitions in parallel...")
    started = System.monotonic_time(:millisecond)

    results =
      1..count
      |> Enum.map(fn index ->
        Task.async(fn ->
          args = ["test", "--partitions", Integer.to_string(count) | rest]
          {output, status} = mix(args, env(index))
          {index, output, status}
        end)
      end)
      |> Task.await_many(:infinity)

    for {index, output, status} <- results do
      Mix.shell().info("\n===== partition #{index}/#{count} (exit #{status}) =====\n")
      Mix.shell().info(String.trim_trailing(output))
    end

    elapsed = System.monotonic_time(:millisecond) - started
    failed = for {index, _, status} <- results, status != 0, do: index

    Mix.shell().info("\n#{count} partitions finished in #{Float.round(elapsed / 1000, 1)}s")

    if failed != [] do
      Mix.raise("Partitions #{Enum.join(failed, ", ")} failed")
    end
  end

  defp parse_args([count | rest]) do
    case Integer.parse(count) do
      {n, ""} when n > 0 -> {n, rest}
      _ -> {default_count(), [count | rest]}
    end
  end

  defp parse_args([]), do: {default_count(), []}

  defp default_count, do: min(System.schedulers_online(), @max_default)

  defp env(index) do
    [
      {"MIX_ENV", "test"},
      {"MIX_TEST_PARTITION", Integer.to_string(index)},
      # The project is already compiled; the lock would make the partitions
      # wait for (or trip over) each other.
      {"MIX_OS_CONCURRENCY_LOCK", "false"}
    ]
  end

  # Run `mix` in a child OS process and fail loudly if it fails.
  defp mix!(args, env) do
    case mix(args, env) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("mix #{Enum.join(args, " ")} failed (#{status}):\n#{output}")
    end
  end

  # Run `mix` in a child OS process, capturing its output.
  defp mix(args, env) do
    {command, args} =
      case :os.type() do
        {:win32, _} -> {"cmd", ["/c", "mix" | args]}
        _ -> {"mix", args}
      end

    System.cmd(command, args, env: env, stderr_to_stdout: true)
  end
end
