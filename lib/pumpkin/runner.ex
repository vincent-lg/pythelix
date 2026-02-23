defmodule Pumpkin.Runner do
  @moduledoc """
  Walks each Feature → Scenario → Step, runs them in an Ecto.Sandbox
  and aggregates a simple pass/fail report.
  """

  alias Pumpkin.{Parser, StepRegistry}

  def run do
    stats = %{passed: 0, failed: 0}
    Parser.load_all()
    |> Enum.reduce(stats, &run_feature/2)
    |> print_summary()
  end

  defp run_feature(%Gherkin.Elements.Feature{file: path} = feature, stats) do
    IO.puts("\nFeature: #{feature.name} (#{path})")
    Enum.reduce(feature.scenarios, stats, fn
      %Gherkin.Elements.Scenario{} = scenario, acc -> run_scenario(scenario, acc)
      _other, acc -> acc
    end)
  end

  defp run_scenario(%Gherkin.Elements.Scenario{name: name, steps: steps}, stats) do
    IO.write("  Scenario: #{name} ... ")

    #Pythelix.Record.Cache.clear()
    ctx = %{}
    caller = self()

    spawn(fn ->
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pythelix.Repo)

      case Enum.reduce_while(steps, ctx, &run_step/2) do
        map when is_map(map) ->
          IO.puts("✔")
          send(caller, %{stats | passed: stats.passed + 1})

        {:error, msg} ->
          IO.puts("✘")
          IO.puts("    #{msg}")
          send(caller, %{stats | failed: stats.failed + 1})
      end
    end)

    receive do
      stats -> stats
    end
  end

  defp run_step(%Gherkin.Elements.Step{keyword: kw, text: text}, ctx) do
    type = step_type(kw)

    case find_match(type, text) do
      {regex, handler} ->
        params = Regex.named_captures(regex, text) || %{}

        result =
          try do
            handler.(params, ctx)
          rescue
            e ->
              {:halt, {:error, Exception.format(:error, e, __STACKTRACE__)}}
          end

        case result do
          {:ok, new_ctx} -> {:cont, new_ctx}
          other -> other
        end

      nil ->
        {:halt, {:error, "no step matches “#{text}” for #{kw}"}}
    end
  end

  defp step_type("Given"), do: :given
  defp step_type("When"),  do: :when
  defp step_type("Then"),  do: :then
  defp step_type(_),       do: :given

  defp find_match(type, text) do
    StepRegistry.all()
    |> Enum.find(fn {t, regex, _} -> t == type and Regex.match?(regex, text) end)
    |> case do
         {_, regex, handler} -> {regex, handler}
         nil -> nil
       end
  end

  defp print_summary(%{passed: p, failed: f}) do
    IO.puts("\nFinished: #{p} passed, #{f} failed")
    if f > 0, do: System.halt(1), else: :ok
  end
end
