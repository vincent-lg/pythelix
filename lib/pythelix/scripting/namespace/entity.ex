defmodule Pythelix.Scripting.Namespace.Entity do
  @moduledoc """
  Defines the namespace specific to an entity stored in the database.
  """

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.Reference
  alias Pythelix.Scripting.Store

  @doc """
  Gets an attribute or method from an entity.
  """
  def getattr(_script, self, "id") do
    entity = Store.get_value(self)

    (entity.id != :virtual && entity.id) || :none
  end

  def getattr(_script, self, "parent") do
    entity = Store.get_value(self)

    parent =
      if parent_id = entity.parent_id do
        Pythelix.Record.get_entity(parent_id)
      else
        :none
      end

    parent
  end

  def getattr(_script, self, "children") do
    entity = Store.get_value(self)

    children = Pythelix.Record.get_children(entity)

    children
  end

  def getattr(_script, self, "location") do
    entity = Store.get_value(self)

    location =
      if location_id = entity.location_id do
        Pythelix.Record.get_entity(location_id)
      else
        :none
      end

    location
  end

  def getattr(_script, self, "contents") do
    entity = Store.get_value(self)

    contents = Pythelix.Record.get_contained(entity)

    contents
  end

  def getattr(script, self, name) do
    entity = Store.get_value(self)

    entity
    |> get_attribute(name, script)
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
    to_value = Store.get_value(to_ref)
    entity = Store.get_value(self)

    case to_value do
      :none ->
        Record.change_parent(entity, nil)
        |> then(& Store.update_reference(self, &1))

        {script, to_ref}

      %Entity{} = parent ->
        Record.change_parent(entity, parent)
        |> then(& Store.update_reference(self, &1))

        {script, to_ref}

      other ->
        {Script.raise(script, AttributeError, "#{inspect(other)} isn't a valid parent"), :none}
    end
  end

  def setattr(script, self, "location", to_ref) do
    to_value = Store.get_value(to_ref)
    entity = Store.get_value(self)

    case to_value do
      :none ->
        Record.change_location(entity, nil)
        |> then(& Store.update_reference(self, &1))

        {script, to_ref}

      %Entity{} = location ->
        Record.change_location(entity, location)
        |> then(& Store.update_reference(self, &1))

        {script, to_ref}

      other ->
        {Script.raise(script, AttributeError, "#{inspect(other)} isn't a valid location"), :none}
    end
  end

  def setattr(script, self, name, to_ref) do
    to_value = Store.get_value(to_ref)
    entity = Store.get_value(self)

    case Record.get_attribute(entity, name) do
      {:extended_property, namespace, name} ->
        apply(namespace, name, [script, self, to_ref])

      _ ->
        case to_ref do
          %Reference{} ->
            Store.bind_entity_attribute(to_ref, entity, name)
            Store.update_reference(to_ref, to_value)

          _ ->
            id_or_key = Entity.get_id_or_key(entity)
            Record.set_attribute(id_or_key, name, to_value)
        end

        {script, to_ref}
    end
  end

  defp get_attribute(entity, name, script) do
    id_or_key = Entity.get_id_or_key(entity)

    case Store.get_bound_entity_attribute(entity, name) do
      nil ->
        attributes = Record.get_attributes(entity)

        case Map.get(attributes, name) do
          nil ->
            {:error, :attribute_not_found}

          {:extended, namespace, name} ->
            {:extended, id_or_key, namespace, name}

          {:extended_property, namespace, name} ->
            apply(namespace, name, [script, entity])

          value ->
            Store.bind_entity_attribute(value, entity, name)
            value
        end

      reference ->
        reference
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
