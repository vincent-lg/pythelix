defmodule Pythelix.Password.Algorithm.Argon2 do
  @behaviour Pythelix.Password.Algorithm

  @atom Argon2

  @doc """
  Returns whether this algorithm is available on this system.
  """
  @impl true
  @spec available() :: boolean()
  def available, do: match?({:module, _}, Code.ensure_loaded(@atom))

  @doc """
  Returns the name of the algorithm as a string.
  """
  @impl true
  @spec name() :: String.t()
  def name, do: "argon2"

  @doc """
  Creates a hash of a clear password given as a string.
  """
  @impl true
  @spec hash(String.t()) :: String.t()
  def hash(password) do
    apply(@atom, :hash_pwd_salt, [password])
  end

  @doc """
  Verify that the hash matches the clear password given.
  """
  @impl true
  @spec verify(String.t(), String.t()) :: boolean()
  def verify(hash, password) do
    apply(@atom, :verify_pass, [password, hash])
  end
end
