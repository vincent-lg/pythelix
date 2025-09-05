defmodule Pythelix.Command.Signature do
  @moduledoc """
  Helper for method signatures.
  """

  alias Pythelix.Command.Signature.Parser

  def constraints(string) do
    with {:ok, args, "", _, _, _} <- Parser.definition(string),
         constraints <- build_constraints(args) do
      constraints
    else
      error -> error
    end
  end

  defp build_constraints(args) do
    with name <- extract_name(args),
         processed_args <- extract_args(args) do
      {name, processed_args}
    end
  end

  defp extract_name(args) do
    args
    |> Enum.find_value("not set", fn
      {:var, name} -> name
      _ -> nil
    end)
  end

  defp extract_args(args) do
    args
    |> Stream.filter(fn
      {:arg, [var: "self"]} -> false
      {:arg, _} -> true
      _ -> false
    end)
    |> Stream.map(fn
      {:arg, [{:var, arg}, {:hint, hint}, {:default, default}]} ->
        {arg, [keyword: arg, type: hint, default: default]}

      {:arg, [{:var, arg}, {:default, default}]} ->
        {arg, [keyword: arg, default: default]}

      {:arg, [{:var, arg}, {:hint, hint},]} ->
        {arg, [keyword: arg, type: hint]}

      {:arg, [{:var, arg}]} ->
        {arg, [keyword: arg]}
    end)
    |> Enum.reduce([], fn {key, constraint}, acc ->
      [{key, [{:index, length(acc)} | constraint]} | acc]
    end)
    |> Enum.reverse()
  end
end
