defmodule Pythelix.Plugin.Requirement do
  @moduledoc """
  Versions and version requirements, as plugin authors write them.

  A manifest says `>=0.9` or `>=1.0, <2.0`. `Version` understands neither: it
  wants three numbers and its own `and`. This is where one becomes the other, so
  that authors can write what reads naturally.

      satisfied?("1.2.0", ">=1.0")          #=> true
      satisfied?("2.0.0", ">=1.0, <2.0")    #=> false
      satisfied?("1.5.0", "~>1.2")          #=> true
      satisfied?("1.5.0", "*")              #=> true
  """

  @clause ~r/^(==|>=|<=|>|<|~>|!=)?\s*(\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.+-]+)?)$/

  @doc """
  Whether a version is written in a way we can read.
  """
  @spec valid_version?(term()) :: boolean()
  def valid_version?(version) when is_binary(version) do
    match?({:ok, _}, version |> complete() |> Version.parse())
  end

  def valid_version?(_version), do: false

  @doc """
  Whether a requirement is written in a way we can read.
  """
  @spec valid?(term()) :: boolean()
  def valid?(requirement) when is_binary(requirement), do: parse(requirement) != :error
  def valid?(_requirement), do: false

  @doc """
  Whether a version meets a requirement. No requirement at all is always met.
  """
  @spec satisfied?(binary(), binary() | nil) :: boolean()
  def satisfied?(_version, nil), do: true

  def satisfied?(version, requirement) do
    case {version |> complete() |> Version.parse(), parse(requirement)} do
      {{:ok, version}, {:ok, requirement}} ->
        Version.match?(version, requirement, allow_pre: true)

      _unreadable ->
        false
    end
  end

  @doc """
  Compare two versions, as `Version.compare/2` does.
  """
  @spec compare(binary(), binary()) :: :lt | :eq | :gt
  def compare(first, second), do: Version.compare(complete(first), complete(second))

  @doc """
  The version of the engine running.
  """
  @spec engine_version() :: binary()
  def engine_version do
    Application.load(:pythelix)

    :pythelix |> Application.spec(:vsn) |> to_string()
  end

  defp parse(requirement) do
    clauses =
      requirement
      |> String.split(",")
      |> Enum.map(&clause(String.trim(&1)))

    with false <- :error in clauses,
         {:ok, parsed} <- clauses |> Enum.join(" and ") |> Version.parse_requirement() do
      {:ok, parsed}
    else
      _unreadable -> :error
    end
  end

  defp clause("*"), do: ">= 0.0.0-0"

  defp clause(text) do
    case Regex.run(@clause, text) do
      nil -> :error
      # `~> 1.2` and `~> 1.2.0` don't mean the same: leave its precision alone.
      [_, "~>", version] -> "~> #{version}"
      [_, "", version] -> "== #{complete(version)}"
      [_, operator, version] -> "#{operator} #{complete(version)}"
    end
  end

  # `1` and `1.2` are versions to an author, and not to `Version`.
  defp complete(version) do
    {numbers, suffix} = split_suffix(version)
    missing = max(0, 3 - length(String.split(numbers, ".")))

    numbers <> String.duplicate(".0", missing) <> suffix
  end

  defp split_suffix(version) do
    case Regex.run(~r/^([^-+]*)(.*)$/s, version) do
      [_, numbers, suffix] -> {numbers, suffix}
    end
  end
end
