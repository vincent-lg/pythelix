defmodule Pythelix.AttributesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pythelix.Attributes` context.
  """

  @doc """
  Generate a attribute.
  """
  def attribute_fixture(attrs \\ %{}) do
    {:ok, attribute} =
      attrs
      |> Enum.into(%{
        name: "some name",
        value: "some value"
      })
      |> Pythelix.Attributes.create_attribute()

    attribute
  end
end
