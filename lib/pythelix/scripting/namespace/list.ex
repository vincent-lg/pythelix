defmodule Pythelix.Scripting.Namespace.List do
  @moduledoc """
  Module defining the list object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet append(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    former = Script.get_value(script, namespace.self, recursive: false)

    script =
      script
      |> Script.update_reference(namespace.self, List.insert_at(former, -1, namespace.value))

    {script, :none}
  end
end
