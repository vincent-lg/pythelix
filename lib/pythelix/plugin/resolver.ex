defmodule Pythelix.Plugin.Resolver do
  @moduledoc """
  Work out which versions to install, given what's asked and what's published.

  It takes the most recent version that fits the engine and everything that
  depends on it, and follows that version's own dependencies. It doesn't explore
  alternatives: when two plugins can't agree, it says so, by name. This registry
  is small and hand-reviewed, and a message a builder can act on is worth more
  than a solver.
  """

  alias Pythelix.Plugin.Requirement

  @type request :: {binary(), binary() | nil}
  @type choice :: {binary(), binary(), map()}

  @doc """
  Choose versions.

  - `requests`: the plugins asked for, each with a requirement or `nil`;
  - `index`: what's published (see `Pythelix.Plugin.Registry`);
  - `installed`: what's already there, as `%{key => version}`, kept as it is
    unless it's among the requests;
  - `constraints`: requirements coming from outside, as `[{key, requirement, who}]`.
    An update passes what the plugins it isn't touching require.

  Returns the plugins to fetch, as `{key, version, index entry}`.
  """
  @spec plan([request()], map(), map(), [{binary(), binary(), binary()}]) ::
          {:ok, [choice()]} | {:error, binary()}
  def plan(requests, index, installed, constraints \\ []) do
    state = %{
      index: index,
      installed: Map.drop(installed, Enum.map(requests, &elem(&1, 0))),
      required: Enum.group_by(constraints, &elem(&1, 0), &{elem(&1, 1), elem(&1, 2)}),
      chosen: %{}
    }

    queue = Enum.map(requests, fn {key, requirement} -> {key, requirement, "you"} end)

    with {:ok, state} <- walk(queue, state) do
      choices =
        state.chosen
        |> Enum.sort()
        |> Enum.map(fn {key, version} -> {key, version, index[key][version]} end)

      {:ok, choices}
    end
  end

  defp walk([], state), do: {:ok, state}

  defp walk([{key, requirement, who} | rest], state) do
    state = add_requirement(state, key, requirement, who)

    case Map.fetch(state.installed, key) do
      {:ok, version} ->
        with :ok <- check_installed(state, key, version) do
          walk(rest, state)
        end

      :error ->
        with {:ok, version} <- pick(state, key) do
          choose(key, version, rest, state)
        end
    end
  end

  defp add_requirement(state, _key, nil, _who), do: state

  defp add_requirement(state, key, requirement, who) do
    update_in(state.required, fn required ->
      Map.update(required, key, [{requirement, who}], &[{requirement, who} | &1])
    end)
  end

  defp choose(key, version, rest, state) do
    if state.chosen[key] == version do
      walk(rest, state)
    else
      entry = state.index[key][version]

      dependencies =
        entry
        |> Map.get("depends", %{})
        |> Enum.sort()
        |> Enum.map(fn {dependency, requirement} -> {dependency, requirement, key} end)

      walk(dependencies ++ rest, put_in(state.chosen[key], version))
    end
  end

  defp check_installed(state, key, version) do
    requirements = Map.get(state.required, key, [])

    case Enum.find(requirements, fn {req, _who} -> not Requirement.satisfied?(version, req) end) do
      nil ->
        :ok

      {requirement, who} ->
        {:error,
         "#{who} needs #{key} #{requirement}, and #{key} #{version} is installed. " <>
           "Try updating #{key}."}
    end
  end

  defp pick(state, key) do
    case Map.fetch(state.index, key) do
      {:ok, versions} ->
        requirements = Map.get(state.required, key, [])

        versions
        |> Enum.filter(fn {_version, entry} -> fits_engine?(entry) end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.filter(&meets_all?(&1, requirements))
        |> Enum.sort(&(Requirement.compare(&1, &2) != :lt))
        |> case do
          [version | _older] -> {:ok, version}
          [] -> {:error, explain_nothing_fits(key, versions, requirements)}
        end

      :error ->
        {:error, "There is no plugin called #{key} in the registry."}
    end
  end

  defp fits_engine?(entry) do
    Requirement.satisfied?(Requirement.engine_version(), Map.get(entry, "pythelix"))
  end

  defp meets_all?(version, requirements) do
    Enum.all?(requirements, fn {req, _who} -> Requirement.satisfied?(version, req) end)
  end

  defp explain_nothing_fits(key, versions, requirements) do
    published = versions |> Map.keys() |> Enum.sort() |> Enum.join(", ")

    needs =
      Enum.map_join(requirements, ", ", fn {requirement, who} -> "#{who} needs #{requirement}" end)

    needs = if needs == "", do: "", else: " (#{needs})"

    "No version of #{key} fits#{needs} on Pythelix #{Requirement.engine_version()}. " <>
      "Published: #{published}."
  end
end
