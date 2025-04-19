defmodule Pythelix.Scripting.Namespace.List do
  @moduledoc """
  Module defining the list object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  defmet append(script, self, args, _kwargs) do
    [value] = args
    former = Script.get_value(script, self)

    script =
      script
      |> Script.update_reference(self, List.insert_at(former, -1, value))

    {script, nil}
  end
end
