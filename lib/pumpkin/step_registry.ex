defmodule Pumpkin.StepRegistry do
  @moduledoc """
  A very simple ETS-backed registry of `{type, regex, handler_fun}`.
  """

  @table :pumpkin_steps

  @doc "Store a step matcher."
  def register(type, %Regex{} = regex, handler) when type in [:given, :when, :then] do
    :ets.insert(@table, {type, regex, handler})
  end

  @doc "List all registered step matchers."
  def all, do: :ets.tab2list(@table)
end
