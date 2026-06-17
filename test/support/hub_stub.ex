defmodule Pythelix.Test.HubStub do
  @moduledoc """
  A plain-module stub for `Pythelix.Game.Hub` message routing, used in tests.

  Configured via `game_hub: Pythelix.Test.HubStub` in config/test.exs.
  The `hub()` helper in `names.ex` calls this module's
  `mark_client_with_message/3` instead of the gen_statem version, so
  no process is involved and the call is synchronous.

  The real `Pythelix.Game.Hub` gen_statem still runs in the supervision
  tree and handles task execution as usual.
  """

  alias Pythelix.Record

  @doc "Synchronous drop-in for `Pythelix.Game.Hub.mark_client_with_message/4`."
  def mark_client_with_message(client_id, message, pid, _opts \\ []) do
    if is_pid(pid) and Process.alive?(pid) do
      send(pid, {:message, message})
    end

    if client_id != nil do
      Record.set_attribute(client_id, "last_msg", message)
    end
  end
end
