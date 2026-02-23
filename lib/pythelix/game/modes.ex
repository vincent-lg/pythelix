defmodule Pythelix.Game.Modes do
  @moduledoc """
  Defines the structure of a game mode, placed on an entity.

  By default, a character in Pythelix has several game modes: these are menus
  with (possibly) different controlling entities. A character can switch
  game mode just for a command or more permanently, using "a pipe syntax".
  It is possible to remove game modes from characters and add them to other
  entities depending on the need.
  """

  alias Pythelix.{Entity, Record}
  alias Pythelix.Game.Modes

  defstruct active: 0, game_modes: [{"menu/game", nil}]

  @typedoc "an owner of a game mode"
  @type owner() :: nil | integer() | String.t()

  @typedoc "the list of game modes"
  @type t() :: %{active: integer(), game_modes: [{String.t(), owner()}]}

  @doc """
  Get the active game mode as a tuple: {menu entity, owner entity}
  """
  @spec get_active(t(), Entity.t()) :: {Entity.t(), nil | Entity.t()}
  def get_active(%Modes{active: active, game_modes: modes}, %Entity{} = owner) do
    case Enum.at(modes, active, {"menu/game", nil}) do
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
  Add a new menu at the top of game modes.
  """
  @spec add(t(), Entity.t(), nil | Entity.t(), list) :: t()
  def add(%Modes{} = mode, %Entity{} = menu, owner, opts \\ []) do
    menu_id_or_key = Entity.get_id_or_key(menu)
    owner_id_or_key = (owner && Entity.get_id_or_key(owner)) || nil

    %{mode | game_modes: [{menu_id_or_key, owner_id_or_key} | mode.game_modes]}
    |> then(fn mode ->
      if opts[:active] do
        %{mode | active: 0}
      else
        mode
      end
    end)
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
      nil ->
        :error

      index ->
        %{mode | game_modes: List.delete_at(mode.game_modes, index)}
        |> then(fn mode ->
          if index < mode.active do
            {:ok, %{mode | active: mode.active - 1}}
          else
            {:ok, mode}
          end
        end)
    end
  end
end
