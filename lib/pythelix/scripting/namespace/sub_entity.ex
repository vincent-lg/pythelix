defmodule Pythelix.Scripting.Namespace.SubEntity do
  @moduledoc """
  Defines the namespace specific to a stub.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Object.Dict

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end
  @doc """
  Gets an attribute or method from a sub entity.
  """
  def getattr(_script, self, name) do
    sub = Store.get_value(self, recursive: false)
    data = Store.get_value(sub.data, recursive: false)

    data
    |> get_attribute(name)
    |> maybe_get_method(sub, self, name)
  end

  @doc """
  Sets an attribute to a sub entity.
  """
  def setattr(script, self, name, to_ref) do
    sub = Store.get_value(self, recursive: false)
    data = Store.get_value(sub.data, recursive: false)
    new_data = Dict.put(data, name, to_ref)
    to_value = Store.get_value(to_ref)
    Store.update_reference(to_ref, to_value)
    Store.update_reference(sub.data, new_data)

    {script, :none}
  end

  defp get_attribute(data, name) do
    case Dict.get(data, name) do
      nil ->
        {:error, :attribute_not_found}

      value ->
        value
    end
  end

  defp maybe_get_method({:error, :attribute_not_found}, sub, self, name) do
    methods = Record.get_methods(sub.base)

    case Map.get(methods, name) do
      nil ->
        :none

      method ->
        %Callable.SubMethod{entity: sub.base.key, sub: self, name: name, method: method}
    end
  end

  defp maybe_get_method(other, _sub, _self, _name), do: other

  defp repr(script, self) do
    Store.get_value(self)
    |> then(& {script, "#{&1.base.key}#{Display.repr(script, &1.data)}"})
  end
end
