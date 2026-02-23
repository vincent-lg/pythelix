defmodule Pythelix.Scripting.Namespace.GameModes do
  @moduledoc """
  Namespace for managing character game modes.

  This namespace provides methods to manipulate the game modes structure
  that allows characters to switch between different menu/entity contexts.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Game.Modes
  alias Pythelix.Scripting.Interpreter.Script

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet add(script, namespace), [
    {:menu, index: 0, keyword: "menu", type: {:entity, "generic/menu"}},
    {:owner, index: 1, keyword: "owner", type: :entity, default: nil},
    {:default, keyword: "default", type: :bool, default: true}
  ] do
    game_modes = Store.get_value(namespace.self)
    menu = Store.get_value(namespace.menu)
    owner = Store.get_value(namespace.owner)
    opts =
      if namespace.default do
        [default: true]
      else
        []
      end

    game_modes = Modes.add(game_modes, menu, owner, opts)
    Store.update_reference(namespace.self, game_modes)

    {script, :none}
  end

  defmet remove(script, namespace), [
    {:menu, index: 0, keyword: "menu", type: {:entity, "generic/menu"}},
    {:owner, index: 1, keyword: "owner", type: :entity, default: nil}
  ] do
    game_modes = Store.get_value(namespace.self)
    menu = Store.get_value(namespace.menu)
    owner = Store.get_value(namespace.owner)

    case Modes.remove(game_modes, menu, owner) do
      :error ->
        message = "cannot remove the mode #{inspect(menu)} "
        ownership =
          if owner do
            "with owner #{inspect(owner)}"
          else
            "regardless of ownership"
          end

        {Script.raise(script, ValueError, message <> ownership), :none}

      {:ok, game_modes} ->
        Store.update_reference(namespace.self, game_modes)
        {script, :none}
    end
  end
end
