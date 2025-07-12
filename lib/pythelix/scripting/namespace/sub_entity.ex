defmodule Pythelix.Scripting.Namespace.SubEntity do
  @moduledoc """
  Defines the namespace specific to a stub.
  """

  alias Pythelix.Record
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Store

  @doc """
  Gets an attribute or method from a sub entity.
  """
  def getattr(_script, self, name) do
    sub = Store.get_value(self)

    sub
    |> get_attribute(name)
    |> maybe_get_method(sub, name)
  end

  @doc """
  Sets an attribute to a sub entity.
  """
  def setattr(script, self, name, to_ref) do
    sub = Store.get_value(self, recursive: false)
    to_value = Store.get_value(to_ref)
    sub = %{sub | data: Dict.put(sub.data, name, to_value)}
    Store.update_reference(self, sub)

    {script, :none}
  end

  defp get_attribute(sub, name) do
    case Dict.get(sub.data, name) do
      nil ->
        {:error, :attribute_not_found}

      value ->
        value
    end
  end

  defp maybe_get_method({:error, :attribute_not_found}, sub, name) do
    methods = Record.get_methods(sub.base)

    case Map.get(methods, name) do
      nil ->
        :none

      method ->
        %Callable.Method{entity: sub.base.key, name: name, method: method}
    end
  end

  defp maybe_get_method(other, _sub, _name), do: other
end
