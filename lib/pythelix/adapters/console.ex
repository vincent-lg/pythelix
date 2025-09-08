defmodule Pythelix.Adapters.Console do
  @behaviour Pythelix.Ports.Console
  @doc """
  Display text in the console.
  """
  @impl true
  @spec puts(iodata()) :: :ok
  def puts(msg), do: IO.puts(msg)

  @doc """
  Read data from the console (usually stdin).
  """
  @impl true
  @spec gets(iodata()) :: String.t() | nil
  def gets(prompt), do: IO.gets(prompt)

  @doc """
  Halt the console.
  """
  @impl true
  @spec halt(non_neg_integer()) :: no_return()
  def halt(code), do: System.halt(code)
end
