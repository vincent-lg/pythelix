defmodule Pythelix.Scripting.Namespace.GameModes do
  @moduledoc """
  Namespace for managing character game modes.

  This namespace provides methods to manipulate the game modes structure
  that allows characters to switch between different menu/entity contexts.
  Game modes are stored as a structure with an active index and a list of modes,
  where each mode is a tuple of {menu_key, owner_entity_id_or_key}.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Record
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Interpreter.Script

  defmet add(script, namespace), [
    {:menu_key, index: 0, keyword: "menu_key", type: :str},
    {:owner_id, index: 1, keyword: "owner_id", type: :any},
    {:default, keyword: "default", type: :bool, default: false}
  ] do
    game_modes_data = Store.get_value(namespace.self)
    menu_key = Format.String.format(namespace.menu_key)
    owner_id = Store.get_value(namespace.owner_id)

    # Get current modes from the data
    current_modes = game_modes_data

    new_mode = {menu_key, owner_id}
    updated_modes =
      %{current_modes | game_modes: current_modes.game_modes ++ [new_mode]}
      |> then(fn modes ->
        if namespace.default do
          %{modes | active: 0}
        else
          modes
        end
      end)

    Store.update_reference(namespace.self, updated_modes)

    {script, :none}
  end

  defmet remove(script, namespace), [
    {:index, index: 0, keyword: "index", type: :int}
  ] do
    game_modes_data = Store.get_value(namespace.self)
    index = namespace.index

    current_modes = game_modes_data

    if length(current_modes.game_modes) <= 1 do
      # Cannot remove the last game mode
      {Script.raise(script, ValueError, "Cannot remove the last game mode"), :none}
    else
      if index >= 0 and index < length(current_modes.game_modes) do
        new_modes = List.delete_at(current_modes.game_modes, index)
        new_active = if current_modes.active >= index and current_modes.active > 0,
                       do: current_modes.active - 1,
                       else: current_modes.active
        new_active = min(new_active, max(0, length(new_modes) - 1))

        updated_modes = %{current_modes | active: new_active, game_modes: new_modes}

        # Update the data in the parent entity
        Store.update_reference(namespace.self, updated_modes)
      end

      {script, :none}
    end
  end

  defmet get_active(script, namespace), [] do
    game_modes_data = Store.get_value(namespace.self)

    case Enum.at(game_modes_data.game_modes, game_modes_data.active) do
      nil -> {script, :none}
      {menu_key, owner_id} ->
        # Return a dictionary with the active mode info
        active_info = %{"menu_key" => menu_key, "owner_id" => owner_id}
        {script, active_info}
    end
  end

  defmet set_active(script, namespace), [
    {:index, index: 0, keyword: "index", type: :int}
  ] do
    game_modes_data = Store.get_value(namespace.self)
    index = namespace.index

    current_modes = game_modes_data

    if index >= 0 and index < length(current_modes.game_modes) do
      updated_modes = %{current_modes | active: index}

      # Update the data in the parent entity
      parent_entity = get_parent_entity(namespace.self)
      if parent_entity do
        Record.set_attribute(parent_entity, "game_modes", updated_modes)
      end
    end

    {script, :none}
  end

  defmet count(script, namespace), [] do
    game_modes_data = Store.get_value(namespace.self)
    {script, length(game_modes_data.game_modes)}
  end

  defmet list(script, namespace), [] do
    game_modes_data = Store.get_value(namespace.self)

    modes_list = Enum.map(game_modes_data.game_modes, fn {menu_key, owner_id} ->
      %{"menu_key" => menu_key, "owner_id" => owner_id}
    end)

    {script, modes_list}
  end

  # Helper function to find the parent entity that contains this game_modes attribute
  defp get_parent_entity(_game_modes_ref) do
    # This is a simplification - in practice, we'd need to track the parent relationship
    # For now, we'll assume this is called in the context where we can find the parent
    # In a real implementation, this might need to be passed as a parameter or tracked differently
    nil
  end
end