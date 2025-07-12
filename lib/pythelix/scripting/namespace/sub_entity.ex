defmodule Pythelix.Scripting.Namespace.SubEntity do
  @moduledoc """
  Defines the namespace specific to a stub.
  """

  alias Pythelix.Record
  alias Pythelix.SubEntity
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Callable
  alias Pythelix.Scripting.Object.Dict

  @doc """
  Gets an attribute or method from a sub entity.
  """
  def getattr(script, self, name) do
    sub = Script.get_value(script, self)

    sub
    |> get_attribute(name)
    |> maybe_get_method(sub, name)
  end

  @doc """
  Sets an attribute to a sub entity.
  """
  def setattr(script, self, name, to_ref) do
    sub = Script.get_value(script, self, recursive: false)
    to_value = Script.get_value(script, to_ref)
    sub = %{sub | data: Dict.put(sub.data, name, to_value)}
    script = Script.update_reference(script, self, sub)

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
