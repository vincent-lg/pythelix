defmodule Pythelix.Scripting.Object.Console do
  @moduledoc """
  A REPL console object for the Pythello scripting language.

  Holds accumulated input (buffer) and retained variables across
  multiple executions, allowing interactive code evaluation.
  """

  defstruct buffer: nil, variables: %{}

  @type t :: %__MODULE__{
          buffer: nil | String.t(),
          variables: map()
        }
end
