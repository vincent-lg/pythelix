defmodule Pythelix.Entity.StackableTest do
  @moduledoc """
  Tests for stackable entities: cache operations, persistence, and
  interaction with the regular contents API.
  """

  use Pythelix.DataCase

  alias Pythelix.Record
  alias Pythelix.Stackable

  # ---------------------------------------------------------------------------
  # Helpers

  defp make_container, do: Record.create_entity() |> elem(1)
  defp make_stackable_entity(key), do: Record.create_entity(key: key) |> elem(1)

  # ---------------------------------------------------------------------------
  # Adding stackables

  describe "add_stackable" do
    test "adds a stackable entry to a container" do
      container = make_container()
      coin = make_stackable_entity("gold_coin")

      Record.add_stackable(container, coin, 100)

      assert Record.get_stackable_quantity(container, coin) == 100
    end

    test "increments an existing stackable entry" do
      container = make_container()
      coin = make_stackable_entity("silver_coin")

      Record.add_stackable(container, coin, 50)
      Record.add_stackable(container, coin, 30)

      assert Record.get_stackable_quantity(container, coin) == 80
    end

    test "multiple different stackables in the same container" do
      container = make_container()
      gold = make_stackable_entity("gold_c")
      silver = make_stackable_entity("silver_c")

      Record.add_stackable(container, gold, 400)
      Record.add_stackable(container, silver, 200)

      assert Record.get_stackable_quantity(container, gold) == 400
      assert Record.get_stackable_quantity(container, silver) == 200
    end

    test "two separate containers hold independent quantities" do
      container_a = make_container()
      container_b = make_container()
      coin = make_stackable_entity("coin_ind")

      Record.add_stackable(container_a, coin, 10)
      Record.add_stackable(container_b, coin, 25)

      assert Record.get_stackable_quantity(container_a, coin) == 10
      assert Record.get_stackable_quantity(container_b, coin) == 25
    end
  end

  # ---------------------------------------------------------------------------
  # Removing stackables

  describe "remove_stackable" do
    test "decrements the quantity of a stackable entry" do
      container = make_container()
      coin = make_stackable_entity("decr_coin")

      Record.add_stackable(container, coin, 100)
      Record.remove_stackable(container, coin, 40)

      assert Record.get_stackable_quantity(container, coin) == 60
    end

    test "removes the entry completely when quantity reaches zero" do
      container = make_container()
      coin = make_stackable_entity("zero_coin")

      Record.add_stackable(container, coin, 50)
      Record.remove_stackable(container, coin, 50)

      assert Record.get_stackable_quantity(container, coin) == 0

      contents = Record.get_contained(container)
      assert contents == []
    end

    test "removes the entry when quantity goes below zero" do
      container = make_container()
      coin = make_stackable_entity("neg_coin")

      Record.add_stackable(container, coin, 10)
      Record.remove_stackable(container, coin, 999)

      assert Record.get_stackable_quantity(container, coin) == 0

      contents = Record.get_contained(container)
      assert contents == []
    end

    test "removing from a container with no stackable is a no-op" do
      container = make_container()
      coin = make_stackable_entity("ghost_coin")

      Record.remove_stackable(container, coin, 5)

      assert Record.get_stackable_quantity(container, coin) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # get_contained with stackables

  describe "get_contained" do
    test "returns Stackable structs for stackable entries" do
      container = make_container()
      coin = make_stackable_entity("struct_coin")

      Record.add_stackable(container, coin, 75)

      [item] = Record.get_contained(container)

      assert %Stackable{} = item
      assert item.entity.id == coin.id
      assert item.quantity == 75
      assert item.location.id == container.id
    end

    test "returns regular entities unchanged" do
      container = make_container()
      {:ok, regular} = Record.create_entity(location: container)

      contents = Record.get_contained(container)
      assert contents == [regular]
    end

    test "returns a mixed list when both regular entities and stackables are present" do
      container = make_container()
      {:ok, sword} = Record.create_entity(location: container)
      coin = make_stackable_entity("mixed_coin")
      Record.add_stackable(container, coin, 50)

      contents = Record.get_contained(container)

      assert length(contents) == 2

      entities = Enum.filter(contents, &match?(%Pythelix.Entity{}, &1))
      stackables = Enum.filter(contents, &match?(%Stackable{}, &1))

      assert entities == [sword]
      assert length(stackables) == 1
      assert hd(stackables).quantity == 50
    end

    test "insertion order: stackable appended after existing regular entity" do
      container = make_container()
      {:ok, sword} = Record.create_entity(location: container)
      coin = make_stackable_entity("order_coin")
      Record.add_stackable(container, coin, 10)

      [first, second] = Record.get_contained(container)

      assert %Pythelix.Entity{} = first
      assert first.id == sword.id

      assert %Stackable{} = second
      assert second.quantity == 10
    end
  end

  # ---------------------------------------------------------------------------
  # Persistence: saving and reloading from the database

  describe "persistence" do
    test "stackable quantity survives a cache clear and reload" do
      container = make_stackable_entity("persist_room")
      coin = make_stackable_entity("persist_coin")

      Record.add_stackable(container, coin, 150)

      Record.Cache.commit_and_clear()
      container = Record.get_entity(container.id)

      assert Record.get_stackable_quantity(container, coin) == 150
    end

    test "partial removal is persisted correctly" do
      container = make_stackable_entity("partial_room")
      coin = make_stackable_entity("partial_coin")

      Record.add_stackable(container, coin, 100)
      Record.remove_stackable(container, coin, 40)

      Record.Cache.commit_and_clear()
      container = Record.get_entity(container.id)

      assert Record.get_stackable_quantity(container, coin) == 60
    end

    test "fully removed stackable is not present after reload" do
      container = make_stackable_entity("gone_room")
      coin = make_stackable_entity("gone_coin")

      Record.add_stackable(container, coin, 30)
      Record.remove_stackable(container, coin, 30)

      Record.Cache.commit_and_clear()
      container = Record.get_entity(container.id)

      assert Record.get_stackable_quantity(container, coin) == 0
      assert Record.get_contained(container) == []
    end

    test "multiple stackables all survive a cache clear" do
      container = make_stackable_entity("multi_room")
      gold = make_stackable_entity("multi_gold")
      silver = make_stackable_entity("multi_silver")

      Record.add_stackable(container, gold, 300)
      Record.add_stackable(container, silver, 80)

      Record.Cache.commit_and_clear()
      container = Record.get_entity(container.id)

      assert Record.get_stackable_quantity(container, gold) == 300
      assert Record.get_stackable_quantity(container, silver) == 80
    end

    test "get_contained returns correct Stackable structs after reload" do
      container = make_stackable_entity("reload_room")
      coin = make_stackable_entity("reload_coin")

      Record.add_stackable(container, coin, 42)

      Record.Cache.commit_and_clear()
      container = Record.get_entity(container.id)

      [item] = Record.get_contained(container)

      assert %Stackable{} = item
      assert item.quantity == 42
      assert item.location.id == container.id
    end
  end
end
