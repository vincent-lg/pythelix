defmodule Pythelix.CommandCase do
  use ExUnit.CaseTemplate

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Namespace

  using do
    quote do
      import Pythelix.CommandCase

      alias Pythelix.Scripting.Object.Dict
    end
  end

  setup tags do
    Pythelix.DataCase.setup_sandbox(tags)
    :ok
  end

  def run_command(%Entity{} = command, args) do
    Pythelix.Command.build_syntax_pattern(command.key)
    id = :erlang.unique_integer([:positive])
    {:ok, client} = Record.create_entity(key: "client/#{id}")
    Record.set_attribute(client.key, "pid", self())
    Record.set_attribute(client.key, "msg", {:extended, Namespace.Extended.Client, :m_msg})
    Pythelix.Command.Executor.execute({client, nil, command.key, args})
  end
end
