defmodule Pythelix.Scripting.Namespace.Builtin do
  @moduledoc """
  Bulitin module, containing builtin functions in particular.\"""
  """

  use Pythelix.Scripting.Namespace

  deffun function_Entity(script, namespace), [
    {:key, keyword: "key", type: :string, default: nil},
    {:parent, keyword: "parent", type: :entity, default: nil}
  ] do
    opts = [key: namespace.key, parent: namespace.parent]
    {:ok, entity} = Pythelix.Record.create_entity(opts)

    {script, entity}
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
