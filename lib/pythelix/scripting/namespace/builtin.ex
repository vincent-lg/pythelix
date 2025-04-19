defmodule Pythelix.Scripting.Namespace.Builtin do
  @moduledoc """
  Bulitin module, containing builtin functions in particular."""
  """

  use Pythelix.Scripting.Namespace

  deffun function_Entity(script, namespace), [
    {:key, keyword: "key", type: :string, default: nil}
  ] do
    opts = [key: namespace.key]
    {:ok, entity} = Pythelix.Record.create_entity(opts)

    {script, entity}
  end
end
