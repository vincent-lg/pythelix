defmodule Pythelix.Command.Executor do
  @moduledoc """
  Execute a command.

  The `Pythelix.Command.Hub` process is going to spawn tasks to
  run this command in another process.

  """

  alias Pythelix.Entity
  alias Pythelix.Method
  alias Pythelix.Record

  @doc """
  Executes a command.

  The key should lead to the command (a virtual entity). Methods
  on this command will be run in the same process.

  Args:

  * {key: the command key, args: the command arguments in a map}

  """
  @spec execute(map()) :: :ok
  def execute({key, args}) do
    key
    |> get_entity()
    |> maybe_execute(args)
  end

  defp get_entity(key), do: Record.get_entity(key)

  defp maybe_execute(nil, _), do: {:error, "unknown command"}

  defp maybe_execute(%Entity{} = entity, args) do
    case Map.fetch(entity.methods, "run") do
      :error ->
        {:error, "no run method on the command"}

      {:ok, method} ->
        state = %{
          method: method,
          args: [],
          kwargs: args
        }

        Pythelix.Scripting.Executor.execute(state)
    end
  end
end
