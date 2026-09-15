defmodule Pythelix.Game.TickManagerTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true

  alias Pythelix.Entity
  alias Pythelix.Game.Hub
  alias Pythelix.Game.TickManager
  alias Pythelix.Generic
  alias Pythelix.Record

  setup do
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()

    hub = :"tick_hub_#{System.unique_integer([:positive])}"
    {:ok, _hub_pid} = start_supervised({Hub, name: hub, max_ms: 2_000})

    srv = :"tick_mgr_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised({TickManager, name: srv, hub: hub})

    [srv: srv, hub: hub, tick_pid: pid]
  end

  # Submit a sentinel job to the Hub and wait for it. This guarantees any tick
  # jobs queued before it have run and their diffs have been applied.
  defp await_hub(hub, timeout \\ 1000) do
    test_pid = self()
    Hub.run(fn -> send(test_pid, :hub_done) end, hub)
    assert_receive :hub_done, timeout
  end

  defp uniq(prefix), do: "#{prefix}/#{System.unique_integer([:positive])}"

  defp create(key) do
    {:ok, _} = Record.create_entity(key: key)
    Record.get_entity(key)
  end

  defp tickable(key, interval, method \\ "on_tick", code \\ "self.ticked = True\n") do
    entity = create(key)
    Record.set_attribute(key, "tick", interval)
    Record.set_method(key, method, :free, code)
    entity
  end

  defp place(entity, location) do
    Record.change_location(entity, location)
    Record.get_entity(Entity.get_id_or_key(entity))
  end

  # Register an active player (a client owning `character`) so the observation
  # gate can see it.
  defp add_player(character) do
    unless Record.get_entity(Generic.client()) do
      {:ok, _} = Record.create_entity(key: Generic.client())
    end

    parent = Record.get_entity(Generic.client())
    key = uniq("client")
    {:ok, _} = Record.create_entity(key: key, parent: parent)
    Record.set_attribute(key, "owner", character)
    Record.get_entity(key)
  end

  defp ticked?(key) do
    Record.get_attribute(Record.get_entity(key), "ticked") == true
  end

  describe "simple ticks (on_tick)" do
    test "fire when a player shares the room", %{srv: srv, hub: hub} do
      room = create(uniq("room"))
      npc = tickable(uniq("npc"), 1)
      place(npc, room)

      character = create(uniq("char"))
      place(character, room)
      add_player(character)

      TickManager.register(Entity.get_id_or_key(npc), srv)

      Process.sleep(2500)
      await_hub(hub)

      assert ticked?(Entity.get_id_or_key(npc))
    end

    test "do not fire when the room is empty", %{srv: srv, hub: hub} do
      room = create(uniq("room"))
      npc = tickable(uniq("npc"), 1)
      place(npc, room)

      TickManager.register(Entity.get_id_or_key(npc), srv)

      Process.sleep(2500)
      await_hub(hub)

      refute ticked?(Entity.get_id_or_key(npc))
    end

    test "do not fire immediately after registering", %{srv: srv, hub: hub} do
      room = create(uniq("room"))
      npc = tickable(uniq("npc"), 3)
      place(npc, room)

      character = create(uniq("char"))
      place(character, room)
      add_player(character)

      TickManager.register(Entity.get_id_or_key(npc), srv)

      Process.sleep(500)
      await_hub(hub)

      refute ticked?(Entity.get_id_or_key(npc))
    end

    test "stop firing after unregister", %{srv: srv, hub: hub} do
      room = create(uniq("room"))

      npc =
        tickable(uniq("npc"), 1, "on_tick", "self.count = (self.count or 0) + 1\n")

      place(npc, room)

      character = create(uniq("char"))
      place(character, room)
      add_player(character)

      key = Entity.get_id_or_key(npc)
      TickManager.register(key, srv)

      Process.sleep(2500)
      await_hub(hub)

      TickManager.unregister(key, srv)
      count_after = Record.get_attribute(Record.get_entity(key), "count") || 0

      Process.sleep(2000)
      await_hub(hub)

      count_later = Record.get_attribute(Record.get_entity(key), "count") || 0
      assert count_later == count_after
    end
  end

  describe "containment closure" do
    # Z (vehicle) ─ Y (room, player) ─ npc, alpha ─ beta
    #             └ W (room, empty)  ─ npc_w
    test "ticks the player's room subtree and its container chain, not siblings",
         %{srv: srv, hub: hub} do
      vehicle = tickable(uniq("vehicle"), 1)
      room_y = create(uniq("room_y"))
      room_w = create(uniq("room_w"))
      place(room_y, vehicle)
      place(room_w, vehicle)

      npc = tickable(uniq("npc"), 1)
      alpha = create(uniq("alpha"))
      beta = tickable(uniq("beta"), 1)
      place(npc, room_y)
      place(alpha, room_y)
      place(beta, alpha)

      npc_w = tickable(uniq("npc_w"), 1)
      place(npc_w, room_w)

      character = create(uniq("char"))
      place(character, room_y)
      add_player(character)

      for e <- [vehicle, npc, beta, npc_w] do
        TickManager.register(Entity.get_id_or_key(e), srv)
      end

      Process.sleep(2500)
      await_hub(hub)

      # Inside the player's room (and nested) tick; the ancestor vehicle ticks.
      assert ticked?(Entity.get_id_or_key(npc))
      assert ticked?(Entity.get_id_or_key(beta))
      assert ticked?(Entity.get_id_or_key(vehicle))

      # The sibling room's NPC is not observed.
      refute ticked?(Entity.get_id_or_key(npc_w))
    end
  end

  describe "major ticks (on_major_tick)" do
    test "fire even when no player is around", %{srv: srv, hub: hub} do
      npc = tickable(uniq("npc"), 1, "on_major_tick")

      TickManager.register(Entity.get_id_or_key(npc), srv)

      Process.sleep(2500)
      await_hub(hub)

      assert ticked?(Entity.get_id_or_key(npc))
    end
  end

  describe "classification" do
    test "an entity with tick but no method never fires", %{srv: srv, hub: hub} do
      room = create(uniq("room"))
      {:ok, _} = Record.create_entity(key: key = uniq("npc"))
      Record.set_attribute(key, "tick", 1)
      place(Record.get_entity(key), room)

      character = create(uniq("char"))
      place(character, room)
      add_player(character)

      TickManager.register(key, srv)

      Process.sleep(1500)
      await_hub(hub)

      refute ticked?(key)
    end

    test "an entity with a method but no tick never fires", %{srv: srv, hub: hub} do
      room = create(uniq("room"))
      {:ok, _} = Record.create_entity(key: key = uniq("npc"))
      Record.set_method(key, "on_tick", :free, "self.ticked = True\n")
      place(Record.get_entity(key), room)

      character = create(uniq("char"))
      place(character, room)
      add_player(character)

      TickManager.register(key, srv)

      Process.sleep(1500)
      await_hub(hub)

      refute ticked?(key)
    end
  end

  describe "rebuild/2" do
    test "registers descendants that inherit a tick method", %{srv: srv, hub: hub} do
      parent = tickable(uniq("generic_npc"), 1, "on_major_tick")
      {:ok, child} = Record.create_entity(key: child_key = uniq("npc"), parent: parent)
      _ = child

      TickManager.rebuild([parent], srv)

      Process.sleep(2500)
      await_hub(hub)

      assert ticked?(child_key)
    end

    test "drops an entity that is no longer tickable", %{srv: srv, hub: hub} do
      npc = tickable(uniq("npc"), 1, "on_major_tick")
      key = Entity.get_id_or_key(npc)

      TickManager.register(key, srv)

      Process.sleep(2500)
      await_hub(hub)

      assert ticked?(key)

      # Remove the interval and reset the flag; after a rebuild it must not fire.
      Record.set_attribute(key, "tick", nil)
      Record.set_attribute(key, "ticked", false)
      TickManager.rebuild([npc], srv)

      Process.sleep(2000)
      await_hub(hub)

      refute ticked?(key)
    end
  end

  describe "destroyed entities" do
    test "are ignored without crashing", %{srv: srv, hub: hub} do
      npc = tickable(uniq("npc"), 1, "on_major_tick")
      key = Entity.get_id_or_key(npc)

      TickManager.register(key, srv)
      Record.delete_entity(key)

      Process.sleep(2500)
      await_hub(hub)

      assert Process.alive?(GenServer.whereis(srv))
    end
  end
end
