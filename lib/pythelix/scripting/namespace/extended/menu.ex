defmodule Pythelix.Scripting.Namespace.Extended.Menu do
  @moduledoc """
  Module containing the extended methods for the menu entity.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.{Method, Record}

  defmet get_commands(script, namespace), [
    {:entity, index: 0, keyword: "entity", type: :entity}
  ] do
    menu = Store.get_value(namespace.self)
    entity = Store.get_value(namespace.entity)
    commands = Record.get_attribute(menu, "commands", %{})

    # Collect unique command keys from the commands map.
    # The commands map is prefix -> command_key or prefix -> [command_key].
    unique_keys =
      commands
      |> Map.values()
      |> Enum.flat_map(fn
        keys when is_list(keys) -> keys
        key when is_binary(key) -> [key]
        _ -> []
      end)
      |> Enum.uniq()

    # Filter commands by can_run if it exists.
    filtered =
      unique_keys
      |> Enum.filter(fn command_key ->
        case Record.get_entity(command_key) do
          nil ->
            false

          command ->
            case Method.call_entity(command, "can_run", [entity]) do
              false -> false
              _ -> true
            end
        end
      end)
      |> Enum.map(&Record.get_entity/1)
      |> Enum.reject(&is_nil/1)

    {script, filtered}
  end
end
