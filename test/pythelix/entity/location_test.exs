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

    test "uncached A contains B only" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)

      # Clear the cache.
      Record.Cache.commit_and_clear()
      a = Record.get_entity(a.id)
      b = Record.get_entity(b.id)

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

    test "uncached A contains B contains C" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity(location: b)

      # Clear the cache.
      Record.Cache.commit_and_clear()
      a = Record.get_entity(a.id)
      b = Record.get_entity(b.id)
      c = Record.get_entity(c.id)

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

    test "A contains B and then moves to C which already contains D" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity()
      {:ok, d} = Record.create_entity(location: c)
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
      assert Record.get_contained(c) == [d, b]
      assert Record.get_contents(c) == [d, b]

      # Test D
      assert Record.get_locations(d) == [c]
      assert Record.get_location(d) == c
      assert Record.get_contained(d) == []
      assert Record.get_contents(d) == []
    end

    test "A contains B contains C, and B moves to E which is contains in D" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity(location: b)
      {:ok, d} = Record.create_entity()
      {:ok, e} = Record.create_entity(location: d)
      b = Record.change_location(b, e)
      c = Record.get_entity(c.id)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == []
      assert Record.get_contents(a) == []

      # Test B
      assert Record.get_locations(b) == [e, d]
      assert Record.get_location(b) == e
      assert Record.get_contained(b) == [c]
      assert Record.get_contents(b) == [c]

      # Test C
      assert Record.get_locations(c) == [b, e, d]
      assert Record.get_location(c) == b
      assert Record.get_contained(c) == []
      assert Record.get_contents(c) == []

      # Test D
      assert Record.get_locations(d) == []
      assert Record.get_location(d) == nil
      assert Record.get_contained(d) == [e]
      assert Record.get_contents(d) == [e, b, c]

      # Test E
      assert Record.get_locations(e) == [d]
      assert Record.get_location(e) == d
      assert Record.get_contained(e) == [b]
      assert Record.get_contents(e) == [b, c]
    end

    test "uncached A contains B and then moves to C" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity()
      Record.change_location(b, c)

      # Clear the cache.
      Record.Cache.commit_and_clear()
      a = Record.get_entity(a.id)
      b = Record.get_entity(b.id)
      c = Record.get_entity(c.id)

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

    test "uncached A contains B and then moves to C which already contains D" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity()
      {:ok, d} = Record.create_entity(location: c)
      Record.change_location(b, c)

      # Clear the cache.
      Record.Cache.commit_and_clear()
      a = Record.get_entity(a.id)
      b = Record.get_entity(b.id)
      c = Record.get_entity(c.id)
      d = Record.get_entity(d.id)

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
      assert Enum.sort(Record.get_contained(c)) == [b, d]
      assert Enum.sort(Record.get_contents(c)) == [b, d]

      # Test D
      assert Record.get_locations(d) == [c]
      assert Record.get_location(d) == c
      assert Record.get_contained(d) == []
      assert Record.get_contents(d) == []
    end

    test "uncached A contains B contains C, and B moves to E which is contains in D" do
      {:ok, a} = Record.create_entity()
      {:ok, b} = Record.create_entity(location: a)
      {:ok, c} = Record.create_entity(location: b)
      {:ok, d} = Record.create_entity()
      {:ok, e} = Record.create_entity(location: d)
      Record.change_location(b, e)

      # Clear the cache.
      Record.Cache.commit_and_clear()
      a = Record.get_entity(a.id)
      b = Record.get_entity(b.id)
      c = Record.get_entity(c.id)
      d = Record.get_entity(d.id)
      e = Record.get_entity(e.id)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == []
      assert Record.get_contents(a) == []

      # Test B
      assert Record.get_locations(b) == [e, d]
      assert Record.get_location(b) == e
      assert Record.get_contained(b) == [c]
      assert Record.get_contents(b) == [c]

      # Test C
      assert Record.get_locations(c) == [b, e, d]
      assert Record.get_location(c) == b
      assert Record.get_contained(c) == []
      assert Record.get_contents(c) == []

      # Test D
      assert Record.get_locations(d) == []
      assert Record.get_location(d) == nil
      assert Record.get_contained(d) == [e]
      assert Record.get_contents(d) == [e, b, c]

      # Test E
      assert Record.get_locations(e) == [d]
      assert Record.get_location(e) == d
      assert Record.get_contained(e) == [b]
      assert Record.get_contents(e) == [b, c]
    end

    test "virtual, A contains B and then moves to C" do
      {:ok, a} = Record.create_entity(virtual: true, key: "a")
      {:ok, b} = Record.create_entity(virtual: true, key: "b", location: a)
      {:ok, c} = Record.create_entity(virtual: true, key: "c")
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

    test "virtual, A contains B and then moves to C which already contains D" do
      {:ok, a} = Record.create_entity(virtual: true, key: "a")
      {:ok, b} = Record.create_entity(virtual: true, key: "b", location: a)
      {:ok, c} = Record.create_entity(virtual: true, key: "c")
      {:ok, d} = Record.create_entity(virtual: true, key: "d", location: c)
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
      assert Record.get_contained(c) == [d, b]
      assert Record.get_contents(c) == [d, b]

      # Test D
      assert Record.get_locations(d) == [c]
      assert Record.get_location(d) == c
      assert Record.get_contained(d) == []
      assert Record.get_contents(d) == []
    end

    test "virtual, A contains B contains C, and B moves to E which is contains in D" do
      {:ok, a} = Record.create_entity(virtual: true, key: "a")
      {:ok, b} = Record.create_entity(virtual: true, key: "b", location: a)
      {:ok, c} = Record.create_entity(virtual: true, key: "c", location: b)
      {:ok, d} = Record.create_entity(virtual: true, key: "d")
      {:ok, e} = Record.create_entity(virtual: true, key: "e", location: d)
      b = Record.change_location(b, e)
      c = Record.get_entity(c.key)

      # Test A
      assert Record.get_locations(a) == []
      assert Record.get_location(a) == nil
      assert Record.get_contained(a) == []
      assert Record.get_contents(a) == []

      # Test B
      assert Record.get_locations(b) == [e, d]
      assert Record.get_location(b) == e
      assert Record.get_contained(b) == [c]
      assert Record.get_contents(b) == [c]

      # Test C
      assert Record.get_locations(c) == [b, e, d]
      assert Record.get_location(c) == b
      assert Record.get_contained(c) == []
      assert Record.get_contents(c) == []

      # Test D
      assert Record.get_locations(d) == []
      assert Record.get_location(d) == nil
      assert Record.get_contained(d) == [e]
      assert Record.get_contents(d) == [e, b, c]

      # Test E
      assert Record.get_locations(e) == [d]
      assert Record.get_location(e) == d
      assert Record.get_contained(e) == [b]
      assert Record.get_contents(e) == [b, c]
    end
  end
end
