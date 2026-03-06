defmodule Pythelix.Game.Epoch do
  @moduledoc """
  Manages the game epoch state.

  The game epoch is a scalable clock that maps real time to game time.
  State is stored in `:px_cache` under `:game_epoch`.
  """

  alias Pythelix.Record

  @cache_key :game_epoch
  @epoch_entity_key "game_epoch"

  @doc """
  Initialize the epoch from the game_epoch entity.

  Looks for a `game_epoch` entity, reads its `scale` attribute,
  and sets `started_at` if not already set.
  """
  def init do
    case Record.get_entity(@epoch_entity_key) do
      nil ->
        Cachex.put(:px_cache, @cache_key, %{
          scale: 1,
          started_at: nil,
          active: false
        })

        :inactive

      entity ->
        scale = Record.get_attribute(entity, "scale", 1)
        started_at = Record.get_attribute(entity, "started_at")

        started_at =
          if started_at == nil do
            now = System.system_time(:second)
            Record.set_attribute(@epoch_entity_key, "started_at", now)
            now
          else
            started_at
          end

        Cachex.put(:px_cache, @cache_key, %{
          scale: scale,
          started_at: started_at,
          active: true
        })

        # Cache calendar entities
        cache_calendars()

        :ok
    end
  end

  @doc """
  Returns whether a game epoch is configured and active.
  """
  def active? do
    case Cachex.get(:px_cache, @cache_key) do
      {:ok, %{active: active}} -> active
      _ -> false
    end
  end

  @doc """
  Returns the current game clock in game seconds since epoch.
  """
  def get_clock do
    case Cachex.get(:px_cache, @cache_key) do
      {:ok, %{active: true, scale: scale, started_at: started_at}} ->
        real_now = System.system_time(:second)
        trunc((real_now - started_at) * scale)

      _ ->
        0
    end
  end

  @doc """
  Returns the scale factor (game seconds per real second).
  """
  def get_scale do
    case Cachex.get(:px_cache, @cache_key) do
      {:ok, %{scale: scale}} -> scale
      _ -> 1
    end
  end

  @doc """
  Returns the real-time Unix timestamp when the epoch started.
  """
  def get_started_at do
    case Cachex.get(:px_cache, @cache_key) do
      {:ok, %{started_at: started_at}} -> started_at
      _ -> nil
    end
  end

  @doc """
  Reset the epoch clock to zero by setting started_at to now.
  """
  def reset do
    now = System.system_time(:second)
    Record.set_attribute(@epoch_entity_key, "started_at", now)

    case Cachex.get(:px_cache, @cache_key) do
      {:ok, state} ->
        Cachex.put(:px_cache, @cache_key, %{state | started_at: now})

      _ ->
        :ok
    end
  end

  @doc """
  Returns real seconds until the given game_seconds timestamp.
  """
  def real_seconds_until(game_seconds) do
    (game_seconds - get_clock()) / get_scale()
  end

  @doc """
  Cache calendar entities for quick lookup.
  """
  def cache_calendars do
    case Record.get_entity(Pythelix.Generic.calendar()) do
      nil ->
        Cachex.put(:px_cache, :game_calendars, [])

      parent ->
        calendars = Record.get_children(parent)
        Cachex.put(:px_cache, :game_calendars, calendars)
    end
  end

  @doc """
  Get cached calendar entities.
  """
  def get_calendars do
    case Cachex.get(:px_cache, :game_calendars) do
      {:ok, calendars} when is_list(calendars) -> calendars
      _ -> []
    end
  end
end
