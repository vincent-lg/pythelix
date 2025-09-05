defmodule Pythelix.Menu.Mode do
  @moduledoc """
  Configuration module for game mode pipe symbols.

  This module defines the configurable symbols used for switching between
  game modes. The symbols can be configured in the application config:

      config :pythelix, Pythelix.Menu.Mode,
        symbols: [
          next: [">", ")"],
          previous: ["<", "("]
        ]

  Default symbols are ">" for next and "<" for previous.
  """

  @doc """
  Get the configured pipe symbols.

  Returns a keyword list with :next and :previous keys, each containing
  a list of symbols that can be used for navigation.
  """
  @spec get_symbols() :: [next: [String.t()], previous: [String.t()]]
  def get_symbols do
    Application.get_env(:pythelix, __MODULE__, [])[:symbols] || [
      next: [">"],
      previous: ["<"]
    ]
  end

  @doc """
  Check if a string is a next symbol.
  """
  @spec next_symbol?(String.t()) :: boolean()
  def next_symbol?(symbol) do
    next_symbols = Keyword.get(get_symbols(), :next, [])
    symbol in next_symbols
  end

  @doc """
  Check if a string is a previous symbol.
  """
  @spec previous_symbol?(String.t()) :: boolean()
  def previous_symbol?(symbol) do
    previous_symbols = Keyword.get(get_symbols(), :previous, [])
    symbol in previous_symbols
  end

  @doc """
  Get all configured pipe symbols (both next and previous).
  """
  @spec all_symbols() :: [String.t()]
  def all_symbols do
    symbols = get_symbols()
    Keyword.get(symbols, :next, []) ++ Keyword.get(symbols, :previous, [])
  end
end
