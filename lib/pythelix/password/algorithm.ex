defmodule Pythelix.Password.Algorithm do
  @doc """
  Returns whether this algorithm is available on this system.
  """
  @callback available() :: boolean()

  @doc """
  Returns the name of the algorithm as a string.
  """
  @callback name() :: String.t()

  @doc """
  Creates a hash of a clear password given as a string.
  """
  @callback hash(String.t()) :: String.t()

  @doc """
  Verify that the hash matches the clear password given.
  """
  @callback verify(String.t(), String.t()) :: boolean()
end
