defmodule Pythelix.Scripting.Namespace.Builtin do
  @moduledoc """
  Bulitin module, containing builtin functions in particular.\"""
  """

  use Pythelix.Scripting.Namespace

  require Logger

  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Format
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.World

  deffun function_Entity(script, namespace), [
    {:key, keyword: "key", type: :str, default: nil},
    {:parent, keyword: "parent", type: :entity, default: nil},
    {:location, keyword: "location", type: :entity, default: nil}
  ] do
    opts = [key: namespace.key, parent: namespace.parent, location: namespace.location]
    {:ok, entity} = Pythelix.Record.create_entity(opts)

    {script, entity}
  end

  deffun apply(script, namespace), [
    {:file, index: 0, type: :str, default: :all}
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
    {:message, index: 0, type: :str}
  ] do
    message = Format.String.format(namespace.message)
    Logger.info(message)

    {script, :none}
  end

  deffun entity(script, namespace), [
    {:id, index: 0, type: :int, default: nil},
    {:key, keyword: "key", type: :str, default: nil}
  ] do
    if namespace.id == nil and namespace.key == nil do
      message = "you must specify either the entity ID or key"
      {Script.raise(script, ValueError, message), :none}
    else
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

  deffun dict(script, namespace), [
    {:iterable, index: 0, type: :dict, default: nil},
    {:kwargs, kwargs: true},
  ] do
    iterable = Script.get_value(script, namespace.iterable) |> IO.inspect()
    kwargs = namespace.kwargs

    dict =
      case iterable do
        nil ->
          kwargs

        iterable ->
          iterable
          |> Dict.new()
          |> Dict.update(kwargs)
      end

    {script, dict}
  end

  deffun set(script, namespace), [
    {:iterable, index: 0, type: :list, default: nil}
  ] do
    iterable = Script.get_value(script, namespace.iterable, recursive: false)

    set =
      case iterable do
        nil ->
          MapSet.new()

        iterable ->
          MapSet.new(iterable)
      end

    {script, set}
  end

  deffun repr(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    {script, Display.repr(script, namespace.object)}
  end

  deffun str(script, namespace), [
    {:object, index: 0, type: :any}
  ] do
    {script, Display.str(script, namespace.object)}
  end
end
