defmodule Pythelix.Game.Modes do
  @moduledoc """
  Defines the structure of a game mode, placed on an entity.

  By default, a character in Pythelix has several game modes: these are menus
  with (possibly) different controlling entities. A character can switch
  game mode just for a command or more permanently, using "a pipe syntax".
  It is possible to remove game modes from characters and add them to other
  entities depending on the need.

  Two different pointers into that stack are needed, and telling them apart
  is what makes the pipe syntax usable:

  - `active` is where the character *stands*. Plain input goes there, and only
    an explicit move (bare `>` or `<`), an `add` or a `close` changes it.
  - `target` is where *this one input* goes. It is set when the input carries
    pipes and a command (`>look`), so that peeking at a neighbouring menu does
    not drag the character over to it, and it is `nil` the rest of the time.

  So `>look` runs `look` one menu down and leaves the character where it was,
  while a bare `>` moves it for good.
  """

  alias Pythelix.{Entity, Record}
  alias Pythelix.Game.Modes

  defstruct active: 0, game_modes: [{"menu/game", nil}], target: nil

  @typedoc "an owner of a game mode"
  @type owner() :: nil | integer() | String.t()

  @typedoc "the list of game modes"
  @type t() :: %{
          active: integer(),
          game_modes: [{String.t(), owner()}],
          target: nil | integer()
        }

  @doc """
  Fill in the fields a stored mode predates.

  Game modes are persisted as Erlang terms, so a struct read back from the
  database has exactly the fields it had when it was written. Read paths call
  this so that a world saved before a field existed keeps working.
  """
  @spec normalize(t()) :: t()
  def normalize(%Modes{} = mode) when is_map_key(mode, :target), do: mode

  def normalize(%{__struct__: Modes} = mode) do
    struct(Modes, Map.delete(mode, :__struct__))
  end

  @doc """
  Get the index of the mode currently receiving input.

  That is `target` while an input is being piped elsewhere, and `active`
  otherwise. The result is always a valid index.
  """
  @spec target(t()) :: integer()
  def target(%Modes{} = mode) do
    (mode.target || mode.active)
    |> max(0)
    |> min(length(mode.game_modes) - 1)
  end

  @doc """
  Get the game mode receiving input as a tuple: {menu entity, owner entity}
  """
  @spec get_active(t(), Entity.t()) :: {Entity.t(), nil | Entity.t()}
  def get_active(%Modes{} = mode, %Entity{} = owner) do
    get_mode(mode, target(mode), owner)
  end

  @doc """
  Get the game mode at the given index as a tuple: {menu entity, owner entity}
  """
  @spec get_mode(t(), integer(), Entity.t()) :: {Entity.t(), nil | Entity.t()}
  def get_mode(%Modes{game_modes: modes}, index, %Entity{} = owner) do
    case Enum.at(modes, index, {"menu/game", nil}) do
      {menu_key, nil} ->
        {Record.get_entity(menu_key), owner}

      {menu_key, owner_id_or_key} ->
        {Record.get_entity(menu_key), Record.get_entity(owner_id_or_key)}
    end
    |> case do
      {menu, nil} ->
        {menu, owner}

      other ->
        other
    end
  end

  @doc """
  Move the character `count` modes along the stack, wrapping around.

  This is the bare `>` or `<`: the character settles on the new mode, so
  `target` no longer applies.
  """
  @spec move(t(), integer()) :: t()
  def move(%Modes{} = mode, count) do
    total = length(mode.game_modes)

    %{mode | active: Integer.mod(standing(mode) + count, total), target: nil}
  end

  @doc """
  Aim the next input `count` modes along the stack, without moving there.

  This is `>look`: the input is handled by a neighbouring menu, but the
  character stays where it stands.

  Counting is always done from where the character stands, never from a
  previous aim, so two `>look` in a row both reach the same menu.
  """
  @spec aim(t(), integer()) :: t()
  def aim(%Modes{} = mode, count) do
    total = length(mode.game_modes)

    %{mode | target: Integer.mod(standing(mode) + count, total)}
  end

  @doc """
  Aim the next input at the mode the character stands on.
  """
  @spec aim(t()) :: t()
  def aim(%Modes{} = mode), do: %{mode | target: nil}

  @doc """
  Add a new menu at the top of game modes.
  """
  @spec add(t(), Entity.t(), nil | Entity.t(), list) :: t()
  def add(%Modes{} = mode, %Entity{} = menu, owner, opts \\ []) do
    menu_id_or_key = Entity.get_id_or_key(menu)
    owner_id_or_key = (owner && Entity.get_id_or_key(owner)) || nil

    %{mode | game_modes: [{menu_id_or_key, owner_id_or_key} | mode.game_modes]}
    |> then(fn mode ->
      if opts[:active] do
        %{mode | active: 0, target: nil}
      else
        # Everything moved down a slot, so the pointers have to follow.
        %{mode | active: mode.active + 1, target: mode.target && mode.target + 1}
      end
    end)
  end

  @doc """
  Close the mode currently receiving input.

  This is the mode the input came through, which is not necessarily the
  topmost one: with two screens open, closing from the one being looked at
  leaves the other alone. The last remaining mode cannot be closed, since a
  character always needs somewhere to send its input.
  """
  @spec close(t()) :: {:ok, t()} | :error
  def close(%Modes{} = mode) do
    case mode.game_modes do
      [_only] -> :error
      _ -> {:ok, delete_at(mode, target(mode))}
    end
  end

  @doc """
  Remove a mode.
  The first maching mode will be removed. If the owner is specified, filter according to it.
  """
  @spec remove(t(), Entity.t(), nil | Entity.t()) :: {:ok, t()} | :error
  def remove(%Modes{} = mode, %Entity{} = menu, owner) do
    menu_id_or_key = Entity.get_id_or_key(menu)

    filter =
      case owner do
        nil ->
          fn {menu, _owned} -> menu == menu_id_or_key end

        %Entity{} ->
          owner_id_or_key = Entity.get_id_or_key(owner)
          fn {menu, owned} -> menu == menu_id_or_key and owned == owner_id_or_key end

        _ ->
          raise "unsupported owner type"
      end

    Enum.find_index(mode.game_modes, filter)
    |> case do
      nil -> :error
      index -> {:ok, delete_at(mode, index)}
    end
  end

  # Where the character stands, guaranteed to be a valid index.
  defp standing(%Modes{} = mode) do
    mode.active |> max(0) |> min(length(mode.game_modes) - 1)
  end

  defp delete_at(%Modes{} = mode, index) do
    remaining = List.delete_at(mode.game_modes, index)

    %{
      mode
      | game_modes: remaining,
        active: follow(mode.active, index, remaining),
        target: follow(mode.target, index, remaining)
    }
  end

  # Where a pointer ends up once the mode at `index` is gone.
  defp follow(nil, _index, _remaining), do: nil

  defp follow(pointer, index, remaining) do
    cond do
      # The mode it pointed at is the one that went: whatever slid into its
      # place takes over, which is the mode that was underneath.
      pointer == index -> pointer
      # Something above it went, so it slid down a slot.
      pointer > index -> pointer - 1
      true -> pointer
    end
    |> max(0)
    |> min(length(remaining) - 1)
  end
end
