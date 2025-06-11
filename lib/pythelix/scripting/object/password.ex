defmodule Pythelix.Scripting.Object.Password do
  @moduledoc """
  A password hashed by a password algorithm.

  This object is returned by the Pythello `password.hash` function.
  It can then be used to verify it (see the password namespace).
  """

  alias Pythelix.Scripting.Object.Password

  @enforce_keys [:algorithm, :hash]
  defstruct [:algorithm, :hash]

  @type t :: %Password{algorithm: atom(), hash: String.t()}

  def verify(hash, clean_password) do
    hash.algorithm.verify(hash.hash, clean_password)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Password{algorithm: algorithm}, opts) do
      concat(["<Password using ", Inspect.inspect(algorithm.name(), opts), ">"])
    end
  end
end
