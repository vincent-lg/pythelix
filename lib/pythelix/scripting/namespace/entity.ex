defmodule Pythelix.Scripting.Namespace.Entity do
  @moduledoc """
  Defines the namespace specific to an entity stored in the database.
  """

  alias Pythelix.Record
  alias Pythelix.Scripting.Interpreter.Script

  @doc """
  Gets an attribute or method from an entity.
  """
  def getattr(script, self, name) do
    entity = Script.get_value(script, self)

    case name do
      "id" ->
        entity.id

      "parent" ->
        id_or_key = Pythelix.Entity.get_id_or_key(entity)
        parent =
          if parent_id = entity.parent_id do
            Pythelix.Record.get_entity(parent_id)
          else
            :none
          end

        {:getattr, id_or_key, "parent", parent}

      _ ->
        entity
        |> get_attribute(name)
        |> maybe_get_method(entity, name)
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

  defp get_attribute(entity, name) do
    case Map.get(entity.attributes, name) do
      nil ->
        {:error, :attribute_not_found}

      {:parent, id_or_key} ->
        parent =
          id_or_key
          |> Record.get_entity()

        value = Map.fetch!(parent.attributes, name)
        id_or_key = Pythelix.Entity.get_id_or_key(entity)

        {:getattr, id_or_key, name, value}

      value ->
        id_or_key = Pythelix.Entity.get_id_or_key(entity)

        {:getattr, id_or_key, name, value}
    end
  end

  defp maybe_get_method({:error, :attribute_not_found}, entity, name) do
    case Map.get(entity.methods, name) do
      nil -> :none
      method -> method
    end
  end

  defp maybe_get_method(other, _entity, _name), do: other
end
