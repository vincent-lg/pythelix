defmodule Pythelix.Scripting.Namespace.Entity do
  @moduledoc """
  Defines the namespace specific to an entity stored in the database.
  """

  alias Pythelix.Scripting.Interpreter.Script

  @doc """
  Gets an attribute or method from an entity.
  """
  def getattr(script, self, name) do
    entity = Script.get_value(script, self)

    case name do
      "id" ->
        entity.id

      other_name ->
        Map.get(entity.attributes, other_name)
        |> case do
          nil -> :none
          value -> {:getattr, entity.id, name, value}
        end
    end
  end

  @doc """
  Sets an attribute to an entity.
  """
  def setattr(script, self, name, to_ref) do
    to_value = Script.get_value(script, to_ref)
    entity = Script.get_value(script, self)

    case name do
      "id" ->
        {script, :none}

      other_name when is_binary(other_name) ->
        entity = Pythelix.Record.set_attribute(entity.id, name, to_value)
        script = Script.update_reference(script, self, entity)

        {script, {:setattr, entity.id, name, to_ref}}
    end
  end
end
