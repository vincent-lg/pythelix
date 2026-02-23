defmodule Pythelix.Scripting.Namespace.Stackable do
  @moduledoc """
  Defines the namespace specific to a stackable handle.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Interpreter.Script

  defmet __bool__(script, _namespace), [] do
    {script, true}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  @doc """
  Gets an attribute from a stackable handle.
  """
  def getattr(_script, self, "quantity") do
    stackable = Store.get_value(self)
    stackable.quantity
  end

  def getattr(_script, self, "location") do
    stackable = Store.get_value(self)

    stackable.location || :none
  end

  def getattr(script, self, name) do
    stackable = Store.get_value(self)
    entity = stackable.entity
    entity_ref = Store.new_reference(entity, script.id)

    entity
    |> get_attribute(name, script, entity_ref)
    |> maybe_get_method(entity, name)
  end

  @doc """
  Sets an attribute on a stackable handle.
  """
  def setattr(script, self, "location", to_ref) do
    to_value = Store.get_value(to_ref)
    stackable = Store.get_value(self)

    case to_value do
      :none ->
        # Remove from current location
        if stackable.location do
          Record.remove_stackable(stackable.location, stackable.entity, stackable.quantity)
        end

        Store.update_reference(self, %{stackable | location: nil})
        {script, to_ref}

      %Entity{} = new_location ->
        # Remove from old location if any
        if stackable.location do
          Record.remove_stackable(stackable.location, stackable.entity, stackable.quantity)
        end

        # Add to new location
        Record.add_stackable(new_location, stackable.entity, stackable.quantity)

        Store.update_reference(self, %{stackable | location: new_location})
        {script, to_ref}

      other ->
        {Script.raise(script, AttributeError, "#{inspect(other)} isn't a valid location"), :none}
    end
  end

  def setattr(script, _self, "quantity", _to_ref) do
    {Script.raise(script, AttributeError, "can't set attribute"), :none}
  end

  def setattr(script, _self, _name, _to_ref) do
    {Script.raise(script, AttributeError, "can't set attribute on stackable"), :none}
  end

  defp get_attribute(entity, name, script, entity_ref) do
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
            ref = Store.new_reference(value, script.id, entity_ref)
            Store.bind_entity_attribute(ref, entity, name)
            ref
        end

      reference ->
        reference
    end
  end

  defp maybe_get_method({:error, :attribute_not_found}, entity, name) do
    id_or_key = Entity.get_id_or_key(entity)
    methods = Record.get_methods(entity)

    case Map.get(methods, name) do
      nil ->
        :none

      method ->
        %Callable.Method{entity: id_or_key, name: name, method: method}
    end
  end

  defp maybe_get_method(other, _entity, _name), do: other

  defp repr(script, self) do
    stackable = Store.get_value(self)
    key = stackable.entity.key || stackable.entity.id
    {script, "#{key}(x#{stackable.quantity})"}
  end
end
