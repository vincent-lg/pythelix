defmodule Pythelix.Task.Plugin do
  @moduledoc """
  The plugin commands, behind `mix pythelix.plugin` and `bin/plugin`.

  None of them need a running server. Those that change plugins only touch
  files, and say so: the game picks the change up the next time it applies.
  """

  alias Pythelix.Plugin
  alias Pythelix.Task.Scenario

  @usage """
  Usage: plugin <command>

    scenario <key>             play a plugin's scenarios, in isolation
  """

  @doc """
  Run a plugin command. Returns `:ok` or `:error`, leaving the caller to decide
  what to do about it.
  """
  @spec run(binary() | [binary()]) :: :ok | :error
  def run(args) when is_binary(args), do: run(OptionParser.split(args))

  def run(["scenario", key]), do: scenario(key)

  def run(_other) do
    IO.puts(@usage)

    :error
  end

  @doc """
  Run a plugin command and stop the VM with a status saying whether it worked.
  This is what a release's `bin/plugin` calls.
  """
  @spec main(binary() | [binary()]) :: no_return()
  def main(args) do
    case run(args) do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
  end

  defp scenario(key) do
    case Plugin.manifest(key) do
      {:ok, _manifest} ->
        Scenario.prepare()
        Scenario.run_plugin(key)

      {:error, reason} ->
        fail(reason)
    end
  end

  defp fail(message) do
    IO.puts(message)

    :error
  end
end
