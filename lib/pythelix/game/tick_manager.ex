defmodule Pythelix.Game.TickManager do
  @moduledoc """
  Manages per-entity ticking.

  Any entity may tick by declaring a `tick` attribute (the interval in seconds)
  together with a tick method:

    * `on_tick` — a *simple* tick. It only fires when a player is around to see
      it, i.e. when a player shares the entity's location, contains it, or is
      contained by it (see `observed?/3`). Cosmetic and live behavior
      (ambience, idle NPC movement) belongs here.
    * `on_major_tick` — a *major* tick. It always fires, whether or not anyone
      is watching. Reserve it for global or "action-at-a-distance" behavior that
      must advance regardless of observers.

  If an entity defines both, the major tick wins.

  The manager keeps a `registry` of every tick-declaring entity (a small subset
  of the world) and a single `schedule` derived from it, armed by one timer. On
  each fire it ticks every entity due within a one-second window — running major
  ticks unconditionally and simple ticks only when observed — then reschedules
  the next batch (±10% jitter).

  Entities enter the registry through:

    * `rebuild/2` — after a worldlet apply, scanning the applied entities and
      their descendants (so a parent gaining a tick method registers its
      children).
    * `register/2` / `unregister/2` — for entities created or destroyed at
      runtime.
  """

  use GenServer

  require Logger

  alias Pythelix.{Entity, Method, Record}
  alias Pythelix.Game.Hub
  alias Pythelix.Generic

  @type id_or_key :: integer() | binary()

  # Entities due within this window (ms) of a fire are ticked together.
  @window 1_000

  defstruct registry: %{}, schedule: [], timer: nil, hub: Hub

  # Public API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Register (or update) a single entity in the tick registry.

  Re-reads the entity's `tick` attribute and tick methods. If it is no longer
  tickable, it is removed instead. Use this for entities created or modified at
  runtime.
  """
  @spec register(id_or_key(), GenServer.server()) :: :ok
  def register(id_or_key, server \\ __MODULE__) do
    GenServer.cast(server, {:register, id_or_key})
  end

  @doc """
  Remove a single entity from the tick registry.
  """
  @spec unregister(id_or_key(), GenServer.server()) :: :ok
  def unregister(id_or_key, server \\ __MODULE__) do
    GenServer.cast(server, {:unregister, id_or_key})
  end

  @doc """
  Reconcile the registry against a set of entities and their descendants.

  Each given entity (and every descendant) is re-classified: tickable ones are
  added or updated, non-tickable ones are removed. Entities outside the scanned
  subtree are left untouched. Call this after a worldlet apply, passing the
  applied entities.

  Accepts a list of entities, IDs, or keys.
  """
  @spec rebuild([Entity.t() | id_or_key()], GenServer.server()) :: :ok
  def rebuild(entities, server \\ __MODULE__) do
    GenServer.cast(server, {:rebuild, entities})
  end

  @doc """
  Rebuild the whole registry by scanning every stored entity.

  Replaces the registry from scratch. Call this once on startup to register all
  tick-declaring entities, including those created at runtime in a previous
  session.
  """
  @spec rebuild_all(GenServer.server()) :: :ok
  def rebuild_all(server \\ __MODULE__) do
    GenServer.cast(server, :rebuild_all)
  end

  # Callbacks

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{hub: Keyword.get(opts, :hub, Hub)}}
  end

  @impl true
  def handle_cast({:register, id_or_key}, state) do
    {:noreply, state |> apply_registry(reconcile_one(state.registry, id_or_key)) |> refresh()}
  end

  def handle_cast({:unregister, id_or_key}, state) do
    key =
      case Record.get_entity(normalize(id_or_key)) do
        nil -> normalize(id_or_key)
        entity -> Entity.get_id_or_key(entity)
      end

    {:noreply, state |> apply_registry(Map.delete(state.registry, key)) |> refresh()}
  end

  def handle_cast({:rebuild, entities}, state) do
    scanned =
      entities
      |> Enum.flat_map(&with_descendants/1)
      |> Enum.uniq()

    registry = Enum.reduce(scanned, state.registry, &reconcile_one(&2, &1))

    {:noreply, state |> apply_registry(registry) |> refresh()}
  end

  def handle_cast(:rebuild_all, state) do
    registry = Enum.reduce(Record.all_entity_ids(), %{}, &reconcile_one(&2, &1))

    {:noreply, state |> apply_registry(registry) |> refresh()}
  end

  @impl true
  def handle_info(:tick, state) do
    now = now_ms()

    {due, rest} =
      Enum.split_with(state.schedule, fn {_key, at, _iv, _kind} -> at <= now + @window end)

    # Drop entities that have been destroyed rather than rescheduling them forever.
    {alive, dead} =
      Enum.split_with(due, fn {key, _at, _iv, _kind} -> Record.get_entity(key) != nil end)

    fire_due(alive, state.hub)

    registry =
      Enum.reduce(dead, state.registry, fn {key, _, _, _}, acc -> Map.delete(acc, key) end)

    schedule =
      Enum.reduce(alive, rest, fn {key, _at, iv, kind}, acc ->
        [{key, now + iv + jitter(iv), iv, kind} | acc]
      end)

    {:noreply, schedule_next_tick(%{state | registry: registry, schedule: schedule, timer: nil})}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Registry

  # Classify one entity and add/update/remove it in the given registry, keyed by
  # the entity's canonical id-or-key so register/unregister/rebuild always agree.
  defp reconcile_one(registry, id_or_key) do
    case Record.get_entity(normalize(id_or_key)) do
      nil ->
        Map.delete(registry, normalize(id_or_key))

      %Entity{} = entity ->
        key = Entity.get_id_or_key(entity)

        case classify(entity) do
          :skip -> Map.delete(registry, key)
          {:ok, entry} -> Map.put(registry, key, entry)
        end
    end
  end

  # Decide whether and how an entity ticks.
  defp classify(%Entity{} = entity) do
    tick = Record.get_attribute(entity, "tick")

    if is_number(tick) and tick > 0 do
      interval_ms = round(tick * 1000)
      major? = has_method?(entity, "on_major_tick")
      simple? = has_method?(entity, "on_tick")

      cond do
        major? and simple? ->
          Logger.warning(
            "entity #{inspect(Entity.get_id_or_key(entity))} defines both on_tick " <>
              "and on_major_tick; on_major_tick wins"
          )

          {:ok, %{interval_ms: interval_ms, kind: :major}}

        major? ->
          {:ok, %{interval_ms: interval_ms, kind: :major}}

        simple? ->
          {:ok, %{interval_ms: interval_ms, kind: :simple}}

        true ->
          :skip
      end
    else
      :skip
    end
  end

  defp has_method?(entity, name) do
    Record.get_method(entity, name) not in [nil, :nomethod]
  end

  defp with_descendants(entity_or_id_or_key) do
    entity =
      case entity_or_id_or_key do
        %Entity{} = e -> e
        id_or_key -> Record.get_entity(id_or_key)
      end

    case entity do
      nil ->
        []

      %Entity{} = entity ->
        key = Entity.get_id_or_key(entity)
        [key | Enum.flat_map(Record.get_children(entity), &with_descendants/1)]
    end
  end

  # Replace the registry and rebuild the schedule, preserving timing phase for
  # entities that were already scheduled.
  defp apply_registry(state, registry) do
    now = now_ms()
    existing = Map.new(state.schedule, fn {key, at, _iv, _kind} -> {key, at} end)

    schedule =
      Enum.map(registry, fn {key, %{interval_ms: iv, kind: kind}} ->
        at = Map.get(existing, key) || now + iv + jitter(iv)
        {key, at, iv, kind}
      end)

    %{state | registry: registry, schedule: schedule}
  end

  defp refresh(state) do
    state
    |> cancel_timer()
    |> schedule_next_tick()
  end

  defp cancel_timer(%{timer: nil} = state), do: state

  defp cancel_timer(%{timer: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer: nil}
  end

  defp schedule_next_tick(%{schedule: []} = state), do: %{state | timer: nil}

  defp schedule_next_tick(%{schedule: schedule} = state) do
    {_key, soonest, _iv, _kind} = Enum.min_by(schedule, fn {_key, at, _iv, _kind} -> at end)
    delay = max(soonest - now_ms(), 0)
    %{state | timer: Process.send_after(self(), :tick, delay)}
  end

  # Firing

  defp fire_due([], _hub), do: :ok

  defp fire_due(due, hub) do
    sets =
      if Enum.any?(due, fn {_key, _at, _iv, kind} -> kind == :simple end) do
        player_sets()
      else
        nil
      end

    Enum.each(due, fn {key, _at, _iv, kind} ->
      case Record.get_entity(key) do
        nil ->
          :ok

        entity ->
          cond do
            kind == :major -> fire(key, "on_major_tick", hub)
            observed?(entity, sets.locations, sets.ancestors) -> fire(key, "on_tick", hub)
            true -> :ok
          end
      end
    end)
  end

  defp fire(key, method, hub) do
    Hub.run(
      fn ->
        case Record.get_entity(key) do
          nil -> :ok
          entity -> Method.call_entity(entity, method)
        end
      end,
      hub
    )
  end

  # Observation gate

  # An entity is observed when a player shares its location chain: either the
  # entity contains a player / is a player (it is in `ancestors`), or the entity
  # sits inside a player's location (one of its ancestors is in `locations`).
  defp observed?(entity, locations, ancestors) do
    key = Entity.get_id_or_key(entity)

    MapSet.member?(ancestors, key) or
      entity
      |> Record.get_locations()
      |> Enum.any?(fn location -> MapSet.member?(locations, Entity.get_id_or_key(location)) end)
  end

  # Build the two player-derived sets once per fire:
  #   * locations — each player's direct location.
  #   * ancestors — each player plus all of its containers.
  defp player_sets do
    players()
    |> Enum.reduce(%{locations: MapSet.new(), ancestors: MapSet.new()}, fn player, acc ->
      ancestors =
        [
          Entity.get_id_or_key(player)
          | Enum.map(Record.get_locations(player), &Entity.get_id_or_key/1)
        ]
        |> Enum.reduce(acc.ancestors, &MapSet.put(&2, &1))

      locations =
        case Record.get_location_entity(player) do
          nil -> acc.locations
          location -> MapSet.put(acc.locations, Entity.get_id_or_key(location))
        end

      %{locations: locations, ancestors: ancestors}
    end)
  end

  # Active players: the owners of active client entities.
  defp players do
    case Record.get_entity(Generic.client()) do
      nil ->
        []

      client_parent ->
        client_parent
        |> Record.get_children()
        |> Enum.map(fn client -> Record.get_attribute(client, "owner") end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn owner -> Record.get_entity(Entity.get_id_or_key(owner)) end)
        |> Enum.reject(&is_nil/1)
    end
  end

  # Helpers

  defp normalize(%Entity{} = entity), do: Entity.get_id_or_key(entity)
  defp normalize(id_or_key), do: id_or_key

  defp now_ms, do: System.monotonic_time(:millisecond)

  # ±10% jitter on the interval.
  defp jitter(interval_ms) do
    range = div(interval_ms, 10)

    if range > 0 do
      :rand.uniform(range * 2 + 1) - range - 1
    else
      0
    end
  end
end
