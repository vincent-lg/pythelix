defmodule Pythelix.ObjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pythelix.Objects` context.
  """

  @doc """
  Generate a object.
  """
  def object_fixture(attrs \\ %{}) do
    {:ok, object} =
      attrs
      |> Enum.into(%{
        key: "some key"
      })
      |> Pythelix.Objects.create_object()

    object
  end
end
