defmodule Pythelix.Scripting.Namespace.Module.Random do
  @moduledoc """
  Module defining the random module.
  """

  use Pythelix.Scripting.Namespace

  defmet choice(script, namespace), [
    {:collection, index: 0}
  ] do
    collection = Script.get_value(script, namespace.collection) |> IO.inspect()

    {script, Enum.random(collection)}
  end
  defmet randint(script, namespace), [
    {:a, index: 0, type: :int},
    {:b, index: 1, type: :int}
  ] do
    %{a: a, b: b} = namespace

    if b < a do
      {Script.raise(script, ValueError, "empty range #{a}..#{b}"), :none}
    else
      {script, Enum.random(a..b)}
    end
  end

  defmet random(script, _namespace), [] do
    {script, :rand.uniform()}
  end

  defmet randrange(script, namespace), [
    {:start, index: 0, type: :int},
    {:stop, index: 1, type: :int, default: :none},
    {:step, index: 2, type: :int, default: 1}
  ] do
    %{start: start, stop: stop, step: step} = namespace

    {start, stop, step} =
      if stop == :none do
        {0, start, 1}
      else
        {start, stop, step}
      end

    if !valid_range?(start, stop, step) do
      {Script.raise(script, ValueError, "empty range #{start}..#{stop}//#{step}"), :none}
    else
      {script, Enum.random(start..stop//step)}
    end
  end

  defp valid_range?(start, stop, 0), do: false
  defp valid_range?(start, stop, step) when step > 0 and start + step > stop, do: false
  defp valid_range?(start, stop, step) when step < 0 and start + step < stop, do: false
  defp valid_range?(_start, _stop, _step), do: true
end
