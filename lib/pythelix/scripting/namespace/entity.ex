defmodule Pythelix.Scripting.Namespace.Entity do
  @moduledoc """
  Defines the namespace specific to an entity stored in the database.
  """

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Callable

  @doc """
  Gets an attribute or method from an entity.
  """
  def getattr(script, self, "id") do
    entity = Script.get_value(script, self)

    (entity.id != :virtual && entity.id) || :none
  end

  def getattr(script, self, "parent") do
    entity = Script.get_value(script, self)
    id_or_key = Pythelix.Entity.get_id_or_key(entity)

    parent =
      if parent_id = entity.parent_id do
        Pythelix.Record.get_entity(parent_id)
      else
        :none
      end

    {:getattr, id_or_key, "parent", parent}
  end

  def getattr(script, self, "children") do
    entity = Script.get_value(script, self)
    id_or_key = Pythelix.Entity.get_id_or_key(entity)

    children = Pythelix.Record.get_children(entity)

    {:getattr, id_or_key, "children", children}
  end

  def getattr(script, self, "location") do
    entity = Script.get_value(script, self)
    id_or_key = Pythelix.Entity.get_id_or_key(entity)

    location =
      if location_id = entity.location_id do
        Pythelix.Record.get_entity(location_id)
      else
        :none
      end

    {:getattr, id_or_key, "location", location}
  end

  def getattr(script, self, "contents") do
    entity = Script.get_value(script, self)
    id_or_key = Pythelix.Entity.get_id_or_key(entity)

    contents = Pythelix.Record.get_contained(entity)

    {:getattr, id_or_key, "contents", contents}
  end

  def getattr(script, self, name) do
    entity = Script.get_value(script, self)

    entity
    |> get_attribute(name)
    |> maybe_get_method(entity, name)
  end

  @doc """
  Sets an attribute to an entity.
  """
  def setattr(script, _self, "id", _to_ref) do
    {Script.raise(script, AttributeError, "can't set attribute"), :none}
  end

  def setattr(script, _self, "children", _to_ref) do
    {Script.raise(script, AttributeError, "can't set attribute"), :none}
  end

  def setattr(script, _self, "contents", _to_ref) do
    {Script.raise(script, AttributeError, "can't set attribute"), :none}
  end

  def setattr(script, self, "parent", to_ref) do
    to_value = Script.get_value(script, to_ref)
    entity = Script.get_value(script, self)
    id_or_key = Entity.get_id_or_key(entity)

    case to_value do
      :none ->
        Record.change_parent(entity, nil)
        |> then(&Script.update_reference(script, self, &1))
        |> then(& {&1, {:setattr, id_or_key, "parent", to_ref}})

      %Entity{} = parent ->
        Record.change_parent(entity, parent)
        |> then(&Script.update_reference(script, self, &1))
        |> then(& {&1, {:setattr, id_or_key, "parent", to_ref}})

      other ->
        {Script.raise(script, AttributeError, "#{inspect(other)} isn't a valid parent"), :none}
    end
  end

  def setattr(script, self, "location", to_ref) do
    to_value = Script.get_value(script, to_ref)
    entity = Script.get_value(script, self)
    id_or_key = Entity.get_id_or_key(entity)

    case to_value do
      :none ->
        Record.change_location(entity, nil)
        |> then(&Script.update_reference(script, self, &1))
        |> then(& {&1, {:setattr, id_or_key, "location", to_ref}})

      %Entity{} = location ->
        Record.change_location(entity, location)
        |> then(&Script.update_reference(script, self, &1))
        |> then(& {&1, {:setattr, id_or_key, "location", to_ref}})

      other ->
        {Script.raise(script, AttributeError, "#{inspect(other)} isn't a valid location"), :none}
    end
  end

  def setattr(script, self, name, to_ref) do
    to_value = Script.get_value(script, to_ref)
    entity = Script.get_value(script, self)
    id_or_key = Entity.get_id_or_key(entity)

    entity = Pythelix.Record.set_attribute(id_or_key, name, to_value)
    script = Script.update_reference(script, self, entity)

    {script, {:setattr, id_or_key, name, to_ref}}
  end

  defp get_attribute(entity, name) do
    attributes = Record.get_attributes(entity)

    case Map.get(attributes, name) do
      nil ->
        {:error, :attribute_not_found}

      value ->
        id_or_key = Pythelix.Entity.get_id_or_key(entity)

        {:getattr, id_or_key, name, value}
    end
  end

  defp maybe_get_method({:error, :attribute_not_found}, entity, name) do
    id_or_key = Pythelix.Entity.get_id_or_key(entity)
    methods = Record.get_methods(entity)

    case Map.get(methods, name) do
      nil ->
        :none

      method ->
        %Callable.Method{entity: id_or_key, name: name, method: method}
    end
  end

  defp maybe_get_method(other, _entity, _name), do: other
end
