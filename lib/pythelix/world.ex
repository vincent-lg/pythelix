defmodule Pythelix.World do
  @moduledoc """
  Centralized world.

  This is not a process. The `init` functiln will be called during the applicaiton startup.

  """

  @generic_command "generic/command"
  @generic_client "generic/client"
  @worldlet_dir "priv/worldlets"
  @worldlet_pattern "*.txt"

  alias Pythelix.Record
  alias Pythelix.Scripting.Namespace.Extendded

  def init() do
    create_base_command()
    create_base_client()
    process_worldlets()
  end

  defp create_base_command() do
    Record.create_entity(virtual: true, key: @generic_command)
  end

  defp create_base_client() do
    Record.create_entity(virtual: true, key: @generic_client)

    Record.set_attribute(@generic_client, "msg", {:extended, Extended.Client, :msg})
  end

  defp process_worldlets() do
    Path.wildcard("#{@worldlet_dir}/**/#{@worldlet_pattern}")
    |> Enum.map(fn path ->
      case Pythelix.World.File.parse_file(path) do
        {:ok, entities} -> create_worldlet(entities)
        error -> error
      end
    end)
  end

  defp create_worldlet(entities) do
    Enum.map(entities, fn entity -> create_entity(entity) end)
  end

  defp create_entity(entity) do
    {parent, attributes} = Map.pop(entity.attributes, "parent")
    parent = Record.get_entity(parent)
    Record.create_entity(key: entity.key, parent: parent)

    for {name, value} <- attributes do
      Record.set_attribute(entity.key, name, value)
    end

    for {name, code} <- entity.methods do
      Record.set_method(entity.key, name, code)
    end
  end
end
