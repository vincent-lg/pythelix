defmodule Pythelix.Scripting.Entity.LocationTest do
  @moduledoc """
  Module to test the entity API in its location/content relationship.
  """

  use Pythelix.DataCase

  alias Pythelix.Record

  describe "creation" do
    test "A contains B only" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == [b]
      assert Record.get_contents(a) == [b]

      # Test B
      assert Record.get_locations(b) == [a]
      assert Record.get_location(b) == a
      assert Record.get_contained(b) == []
      assert Record.get_contents(b) == []
    end

    test "A contains B contains C" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity(location: b)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == [b]
      assert Record.get_contents(a) == [b, c]

      # Test B
      assert Record.get_locations(b) == [a]
      assert Record.get_location(b) == a
      assert Record.get_contained(b) == [c]
      assert Record.get_contents(b) == [c]

      # Test C
      assert Record.get_locations(c) == [b, a]
      assert Record.get_location(c) == b
      assert Record.get_contained(c) == []
      assert Record.get_contents(c) == []
    end

    test "virtual A contains B only" do
      {:ok, a} = Record.create_entity(virtual: true, key: "a")
      {:ok, b} = Record.create_entity(virtual: true, location: a, key: "b")

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == [b]
      assert Record.get_contents(a) == [b]

      # Test B
      assert Record.get_locations(b) == [a]
      assert Record.get_location(b) == a
      assert Record.get_contained(b) == []
      assert Record.get_contents(b) == []
    end

    test "virtual A contains B contains C" do
      {:ok, a} = Record.create_entity(virtual: true, key: "a")
      {:ok, b} = Record.create_entity(virtual: true, location: a, key: "b")
      {:ok, c} = Record.create_entity(virtual: true, location: b, key: "c")

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == [b]
      assert Record.get_contents(a) == [b, c]

      # Test B
      assert Record.get_locations(b) == [a]
      assert Record.get_location(b) == a
      assert Record.get_contained(b) == [c]
      assert Record.get_contents(b) == [c]

      # Test C
      assert Record.get_locations(c) == [b, a]
      assert Record.get_location(c) == b
      assert Record.get_contained(c) == []
      assert Record.get_contents(c) == []
    end
  end

  describe "change location" do
    test "A contains B and then moves to C" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity()
      b = Record.change_location(b, c)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == []
      assert Record.get_contents(a) == []

      # Test B
      assert Record.get_locations(b) == [c]
      assert Record.get_location(b) == c
      assert Record.get_contained(b) == []
      assert Record.get_contents(b) == []

      # Test C
      assert Record.get_locations(c) == []
      assert Record.get_location(c) == nil
      assert Record.get_contained(c) == [b]
      assert Record.get_contents(c) == [b]
    end
  end
end
