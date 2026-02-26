defmodule Pythelix.Scripting.Exception do
  @moduledoc """
  Exception hierarchy for Pythello scripting language.

  Provides a static hierarchy of exception types mirroring Python's,
  and a `matches?/2` function to check if a caught exception type
  matches a handler type (walking up the parent chain).
  """

  @hierarchy %{
    ZeroDivisionError => ArithmeticError,
    OverflowError => ArithmeticError,
    ArithmeticError => Exception,
    KeyError => LookupError,
    IndexError => LookupError,
    LookupError => Exception,
    ValueError => Exception,
    TypeError => Exception,
    NameError => Exception,
    AttributeError => Exception,
    NotImplementedError => RuntimeError,
    RuntimeError => Exception,
    SyntaxError => Exception,
    StopIteration => Exception,
    Exception => BaseException
  }

  # All valid exception names: hierarchy keys + BaseException
  @valid_exceptions MapSet.new(Map.keys(@hierarchy) ++ [BaseException])

  @doc """
  Check whether an atom is a known exception type.
  """
  @spec valid?(atom()) :: boolean()
  def valid?(exc_atom), do: MapSet.member?(@valid_exceptions, exc_atom)

  @doc """
  Check if `exception` matches `handler_type` by walking the hierarchy.

  A nil handler_type (bare except) matches everything.
  """
  @spec matches?(atom(), atom() | nil) :: boolean()
  def matches?(_exception, nil), do: true
  def matches?(exception, handler_type) when exception == handler_type, do: true

  def matches?(exception, handler_type) do
    case Map.get(@hierarchy, exception) do
      nil -> false
      parent -> matches?(parent, handler_type)
    end
  end
end
