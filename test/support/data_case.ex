defmodule Pythelix.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Pythelix.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Pythelix.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Pythelix.DataCase
    end
  end

  setup tags do
    Pythelix.DataCase.setup_sandbox(tags)
    Pythelix.DataCase.drain_hub_on_exit()
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Pythelix.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Wait, when the test exits, for the global game hub to finish the jobs queued
  so far, before the sandbox owner goes away.

  Scripts that pause (`wait`, `ask`...) resume through the global hub, which
  applies their diffs from its own process. Without this, a test can end while
  the hub is still committing on the test's sandbox connection, which logs a
  "owner exited" disconnection. Registered after the sandbox `on_exit`, so it
  runs before it.
  """
  def drain_hub_on_exit(timeout \\ 1_000) do
    on_exit(fn -> drain_hub(timeout) end)
  end

  @doc """
  Wait for the global game hub to be idle, i.e. to have finished every job
  queued so far and applied its diff. Returns on timeout or if the hub is
  not running.
  """
  def drain_hub(timeout \\ 1_000) do
    if Process.whereis(Pythelix.Game.Hub) do
      Pythelix.Game.Hub.await_idle(Pythelix.Game.Hub, timeout)
    end

    :ok
  catch
    :exit, _ -> :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
