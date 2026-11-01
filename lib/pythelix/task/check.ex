defmodule Pythelix.Task.Check do
  @moduledoc """
  Report what `Pythelix.World.Check` finds, from the command line.

  Used by `mix pythello.check` and by `bin/check` in a release. Unlike applying
  a worldlet, this needs no running server: the worldlets are only read.
  """

  alias Pythelix.Scripting.Diagnostic
  alias Pythelix.World.Check

  @switches [json: :boolean]

  @doc """
  Check the worldlets named by `args` and print the outcome.

  Returns `:ok` when they parse and `:error` when they don't, leaving the
  caller to decide what to do about it.
  """
  @spec run(binary() | [binary()]) :: :ok | :error
  def run(args) when is_binary(args), do: run(OptionParser.split(args))

  def run(args) do
    {opts, paths} = OptionParser.parse!(args, strict: @switches)

    case paths do
      [] -> check(:all, opts)
      [path] -> check(path, opts)
      _ -> fail("Please give a single worldlet file or directory to check.")
    end
  rescue
    error in OptionParser.ParseError -> fail(Exception.message(error))
  end

  @doc """
  Check the worldlets and stop the VM with a status saying whether they parse.

  This is what a release's `bin/check` calls, so that it can gate a build.
  """
  @spec main(binary() | [binary()]) :: no_return()
  def main(args) do
    case run(args) do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
  end

  defp check(path, opts) do
    case Check.run(path) do
      :nofile ->
        fail("No worldlet found at #{inspect(path)}.")

      {:ok, result} ->
        if opts[:json], do: report_json(result), else: report(result)

        (result.diagnostics == [] && :ok) || :error
    end
  end

  defp report_json(result) do
    %{
      files: length(result.files),
      entities: result.entities,
      diagnostics: Enum.map(result.diagnostics, &Diagnostic.to_map/1),
      notices: result.notices
    }
    |> Jason.encode!(pretty: true)
    |> IO.puts()
  end

  defp report(%{diagnostics: []} = result) do
    Enum.each(result.notices, &IO.puts/1)

    IO.puts(
      "Checked #{count(length(result.files), "worldlet")}, " <>
        "#{count(result.entities, "entity", "entities")}: no problem found."
    )
  end

  defp report(result) do
    Enum.each(result.notices, &IO.puts/1)
    Enum.each(result.diagnostics, &IO.puts("\n" <> Diagnostic.format(&1)))

    IO.puts(
      "\nChecked #{count(length(result.files), "worldlet")}: " <>
        "#{count(length(result.diagnostics), "problem")} found."
    )
  end

  defp fail(message) do
    IO.puts(message)

    :error
  end

  defp count(number, singular, plural \\ nil)
  defp count(1, singular, _plural), do: "1 #{singular}"
  defp count(number, singular, nil), do: "#{number} #{singular}s"
  defp count(number, _singular, plural), do: "#{number} #{plural}"
end
