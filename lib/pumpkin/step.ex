defmodule Pumpkin.Step do
  @moduledoc """
  `use Pumpkin.StepDefiner` in your step‐definition modules to
  register Given/When/Then regex → handler mappings.
  """

  defmacro __using__(_opts) do
    quote do
      import Pumpkin.Step, only: [defgiven: 4, defwhen: 4, defthen: 4, assert: 1]
    end
  end

  defmacro defgiven(pattern, group, context, do: block) do
    quote do
      Pumpkin.StepRegistry.register(:given, unquote(pattern), fn group, context ->
        case {group, context} do
          {unquote(group), unquote(context)} ->
            unquote(block)

          other ->
            raise "match error: cannot match #{inspect(other)}"
        end
      end)
    end
  end

  defmacro defwhen(pattern, group, context, do: block) do
    quote do
      Pumpkin.StepRegistry.register(:when, unquote(pattern), fn group, context ->
        case {group, context} do
          {unquote(group), unquote(context)} ->
            unquote(block)

          other ->
            raise "match error: cannot match #{inspect(other)}"
        end
      end)
    end
  end

  defmacro defthen(pattern, group, context, do: block) do
    quote do
      Pumpkin.StepRegistry.register(:then, unquote(pattern), fn group, context ->
        case {group, context} do
          {unquote(group), unquote(context)} ->
            unquote(block)

          other ->
            raise "match error: cannot match #{inspect(other)}"
        end
      end)
    end
  end

  def assert(value) do
    if value do
      {:ok, %{}}
    else
      raise "not a truhy value"
    end
  end
end
