defmodule Pythelix.MethodsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pythelix.Methods` context.
  """

  @doc """
  Generate a method.
  """
  def method_fixture(attrs \\ %{}) do
    {:ok, method} =
      attrs
      |> Enum.into(%{
        name: "some name",
        value: "some value"
      })
      |> Pythelix.Methods.create_method()

    method
  end
end
