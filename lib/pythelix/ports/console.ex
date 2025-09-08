defmodule Pythelix.Ports.Console do
  @moduledoc """
  Console abstraction to handle IO operations.
  """

  @doc """
  Display text in the console.
  """
  @callback puts(iodata()) :: :ok

  @doc """
  Read data from the console (usually stdin).
  """
  @callback gets(iodata()) :: String.t() | nil

  @doc """
  Halt the console.
  """
  @callback halt(non_neg_integer()) :: no_return()
end
