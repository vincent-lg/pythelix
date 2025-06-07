defmodule Pythelix.Scripting.Namespace.Builtin do
  @moduledoc """
  Bulitin module, containing builtin functions in particular.\"""
  """

  use Pythelix.Scripting.Namespace

  require Logger

  alias Pythelix.Scripting.Format
  alias Pythelix.World

  deffun function_Entity(script, namespace), [
    {:key, keyword: "key", type: :string, default: nil},
    {:parent, keyword: "parent", type: :entity, default: nil},
    {:location, keyword: "location", type: :entity, default: nil}
  ] do
    opts = [key: namespace.key, parent: namespace.parent, location: namespace.location]
    {:ok, entity} = Pythelix.Record.create_entity(opts)

    {script, entity}
  end

  deffun apply(script, namespace), [
    {:file, index: 0, type: :string, default: :all}
  ] do
    case World.apply(namespace.file) do
      {:ok, path, number} ->
        {script, "Worldlet applied from #{path}: #{number} entities were added or updated."}

      :nofile ->
        {script, "The specified file #{inspect(namespace.file)} doesn't exist."}

      :error ->
        {script, "An error occurred, applying cancelled."}
    end
  end

  deffun log(script, namespace), [
    {:message, index: 0, type: :string}
  ] do
    message = Format.String.format(namespace.message)
    Logger.info(message)

    {script, :none}
  end
  deffun entity(script, namespace), [
    {:id, index: 0, type: :int, default: nil},
    {:key, keyword: "key", type: :string, default: nil}
  ] do
    entity =
      (namespace.id || namespace.key)
      |> Pythelix.Record.get_entity()
      |> then(fn
        nil -> :none
        valid -> valid
      end)

    {script, entity}
  end
end
