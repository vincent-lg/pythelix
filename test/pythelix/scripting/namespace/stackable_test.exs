defmodule Pythelix.Scripting.Namespace.StackableTest do
  @moduledoc """
  Tests for the Stackable scripting namespace: creating stackable handles,
  reading attributes, transferring via location assignment, and search.match.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Record
  alias Pythelix.Stackable

  # ---------------------------------------------------------------------------
  # Creating stackable handles with the stackable() builtin

  describe "stackable() builtin" do
    test "creates a floating stackable handle with correct quantity" do
      {:ok, _coin} = Record.create_entity(key: "builtin_coin")
      Record.set_attribute("builtin_coin", "stackable", true)

      script = run("""
      coin = stackable(!builtin_coin!, 100)
      qty = coin.quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 100
    end

    test "floating handle has no location" do
      {:ok, _coin} = Record.create_entity(key: "floating_coin")
      Record.set_attribute("floating_coin", "stackable", true)

      script = run("""
      coin = stackable(!floating_coin!, 50)
      loc = coin.location
      """)

      loc = Script.get_variable_value(script, "loc")
      assert loc == :none
    end

    test "repr shows entity key and quantity" do
      {:ok, _coin} = Record.create_entity(key: "repr_coin")
      Record.set_attribute("repr_coin", "stackable", true)

      script = run("""
      coin = stackable(!repr_coin!, 99)
      r = repr(coin)
      """)

      r = Script.get_variable_value(script, "r")
      assert r == "repr_coin(x99)"
    end

    test "raises TypeError when entity does not have stackable: true" do
      {:ok, _sword} = Record.create_entity(key: "plain_sword_ns")

      assert {:error, traceback} = Pythelix.Scripting.eval("""
      s = stackable(!plain_sword_ns!, 1)
      """)

      assert traceback.exception == TypeError
    end
  end

  # ---------------------------------------------------------------------------
  # Delegating attributes to the underlying entity

  describe "attribute delegation" do
    test "reads an attribute from the underlying entity" do
      {:ok, _coin} = Record.create_entity(key: "attr_coin")
      Record.set_attribute("attr_coin", "stackable", true)
      Record.set_attribute("attr_coin", "name", "gold coin")

      script = run("""
      coin = stackable(!attr_coin!, 10)
      n = coin.name
      """)

      n = Script.get_variable_value(script, "n")
      assert n == "gold coin"
    end

    test "quantity returns 1 for a regular entity" do
      {:ok, _sword} = Record.create_entity(key: "plain_sword")

      script = run("""
      qty = !plain_sword!.quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 1
    end

    test "quantity attribute cannot be set on a stackable" do
      {:ok, _coin} = Record.create_entity(key: "readonly_coin")
      Record.set_attribute("readonly_coin", "stackable", true)

      assert {:error, traceback} = Pythelix.Scripting.eval("""
      coin = stackable(!readonly_coin!, 10)
      coin.quantity = 999
      """)

      assert traceback.exception == AttributeError
    end
  end

  # ---------------------------------------------------------------------------
  # Placing a stackable in a container via location assignment

  describe "location assignment — placement" do
    test "setting location places stackable in container" do
      {:ok, room} = Record.create_entity(key: "place_room")
      {:ok, _coin} = Record.create_entity(key: "place_coin")
      Record.set_attribute("place_coin", "stackable", true)

      run("""
      coin = stackable(!place_coin!, 400)
      coin.location = !place_room!
      """)

      assert Record.get_stackable_quantity(room, Record.get_entity("place_coin")) == 400
    end

    test "container contents includes the stackable after placement" do
      {:ok, _room} = Record.create_entity(key: "contents_room")
      {:ok, _coin} = Record.create_entity(key: "contents_coin")
      Record.set_attribute("contents_coin", "stackable", true)

      script = run("""
      coin = stackable(!contents_coin!, 5)
      coin.location = !contents_room!
      found = None
      for item in !contents_room!.contents:
          if item.quantity == 5:
              found = item
          endif
      done
      """)

      found = Script.get_variable_value(script, "found")
      assert %Stackable{quantity: 5} = found
    end

    test "placing twice accumulates quantity in container" do
      {:ok, room} = Record.create_entity(key: "accum_room")
      {:ok, _coin} = Record.create_entity(key: "accum_coin")
      Record.set_attribute("accum_coin", "stackable", true)

      run("""
      a = stackable(!accum_coin!, 100)
      a.location = !accum_room!
      b = stackable(!accum_coin!, 50)
      b.location = !accum_room!
      """)

      assert Record.get_stackable_quantity(room, Record.get_entity("accum_coin")) == 150
    end
  end

  # ---------------------------------------------------------------------------
  # Transferring a stackable between containers

  describe "location assignment — transfer" do
    test "moving stackable from one container to another" do
      {:ok, room} = Record.create_entity(key: "xfer_room")
      {:ok, player} = Record.create_entity(key: "xfer_player")
      {:ok, _coin} = Record.create_entity(key: "xfer_coin")
      Record.set_attribute("xfer_coin", "stackable", true)

      run("""
      coin = stackable(!xfer_coin!, 200)
      coin.location = !xfer_room!
      coin.location = !xfer_player!
      """)

      assert Record.get_stackable_quantity(room, Record.get_entity("xfer_coin")) == 0
      assert Record.get_stackable_quantity(player, Record.get_entity("xfer_coin")) == 200
    end

    test "partial transfer via search.match with limit" do
      {:ok, room} = Record.create_entity(key: "partial_room")
      {:ok, player} = Record.create_entity(key: "partial_player")
      {:ok, _coin} = Record.create_entity(key: "partial_coin")
      Record.set_attribute("partial_coin", "stackable", true)
      Record.set_attribute("partial_coin", "name", "gold coin")

      run("""
      coin = stackable(!partial_coin!, 400)
      coin.location = !partial_room!
      matches = search.match(!partial_room!, "gold", limit=3)
      matches[0].location = !partial_player!
      """)

      coin = Record.get_entity("partial_coin")
      assert Record.get_stackable_quantity(room, coin) == 397
      assert Record.get_stackable_quantity(player, coin) == 3
    end

    test "transferring does not affect unrelated stackables in source" do
      {:ok, room} = Record.create_entity(key: "iso_room")
      {:ok, player} = Record.create_entity(key: "iso_player")
      {:ok, _gold} = Record.create_entity(key: "iso_gold")
      {:ok, _silver} = Record.create_entity(key: "iso_silver")
      Record.set_attribute("iso_gold", "stackable", true)
      Record.set_attribute("iso_silver", "stackable", true)

      run("""
      gold = stackable(!iso_gold!, 100)
      gold.location = !iso_room!
      silver = stackable(!iso_silver!, 50)
      silver.location = !iso_room!
      gold.location = !iso_player!
      """)

      gold = Record.get_entity("iso_gold")
      silver = Record.get_entity("iso_silver")

      assert Record.get_stackable_quantity(room, gold) == 0
      assert Record.get_stackable_quantity(player, gold) == 100
      assert Record.get_stackable_quantity(room, silver) == 50
      assert Record.get_stackable_quantity(player, silver) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Removing a stackable (setting location to None)

  describe "location assignment — removal" do
    test "setting location to None removes the stackable from container" do
      {:ok, room} = Record.create_entity(key: "rm_room")
      {:ok, _coin} = Record.create_entity(key: "rm_coin")
      Record.set_attribute("rm_coin", "stackable", true)

      run("""
      coin = stackable(!rm_coin!, 30)
      coin.location = !rm_room!
      coin.location = None
      """)

      assert Record.get_stackable_quantity(room, Record.get_entity("rm_coin")) == 0
      assert Record.get_contained(room) == []
    end

    test "setting location to None on a floating handle is a no-op" do
      {:ok, _coin} = Record.create_entity(key: "noop_coin")
      Record.set_attribute("noop_coin", "stackable", true)

      script = run("""
      coin = stackable(!noop_coin!, 10)
      coin.location = None
      qty = coin.quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 10
    end
  end

  # ---------------------------------------------------------------------------
  # search.match

  describe "search.match" do
    test "finds a stackable by name attribute" do
      {:ok, room} = Record.create_entity(key: "sm_room")
      {:ok, _coin} = Record.create_entity(key: "sm_coin")
      Record.set_attribute("sm_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("sm_coin"), 100)

      script = run("""
      results = search.match(!sm_room!, "gold")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
      [item] = results
      assert %Stackable{quantity: 100} = item
    end

    test "does not match a stackable when text doesn't fit" do
      {:ok, room} = Record.create_entity(key: "nomatch_room")
      {:ok, _coin} = Record.create_entity(key: "nomatch_coin")
      Record.set_attribute("nomatch_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("nomatch_coin"), 10)

      script = run("""
      results = search.match(!nomatch_room!, "silver")
      """)

      results = Script.get_variable_value(script, "results")
      assert results == []
    end

    test "returns full quantity when no limit is given" do
      {:ok, room} = Record.create_entity(key: "nolimit_room")
      {:ok, _coin} = Record.create_entity(key: "nolimit_coin")
      Record.set_attribute("nolimit_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("nolimit_coin"), 500)

      script = run("""
      results = search.match(!nolimit_room!, "gold")
      qty = results[0].quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 500
    end

    test "limit caps returned quantity to the limit" do
      {:ok, room} = Record.create_entity(key: "limit_room")
      {:ok, _coin} = Record.create_entity(key: "limit_coin")
      Record.set_attribute("limit_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("limit_coin"), 400)

      script = run("""
      results = search.match(!limit_room!, "gold", limit=3)
      qty = results[0].quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 3
    end

    test "limit does not exceed the available quantity" do
      {:ok, room} = Record.create_entity(key: "cap_room")
      {:ok, _coin} = Record.create_entity(key: "cap_coin")
      Record.set_attribute("cap_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("cap_coin"), 2)

      script = run("""
      results = search.match(!cap_room!, "gold", limit=100)
      qty = results[0].quantity
      """)

      qty = Script.get_variable_value(script, "qty")
      assert qty == 2
    end

    test "matches regular entities alongside stackables" do
      {:ok, room} = Record.create_entity(key: "mixed_sm_room")
      {:ok, sword} = Record.create_entity(key: "golden_sword", location: room)
      Record.set_attribute("golden_sword", "name", "golden sword")
      {:ok, _coin} = Record.create_entity(key: "mixed_sm_coin")
      Record.set_attribute("mixed_sm_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("mixed_sm_coin"), 20)

      script = run("""
      results = search.match(!mixed_sm_room!, "gold")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 2

      entities = Enum.filter(results, &match?(%Pythelix.Entity{}, &1))
      stackables = Enum.filter(results, &match?(%Stackable{}, &1))

      assert length(entities) == 1
      assert hd(entities).id == sword.id
      assert length(stackables) == 1
      assert hd(stackables).quantity == 20
    end

    test "custom filter attribute" do
      {:ok, room} = Record.create_entity(key: "custom_filter_room")
      {:ok, _coin} = Record.create_entity(key: "custom_filter_coin")
      Record.set_attribute("custom_filter_coin", "french_name", "pièce d'or")
      Record.add_stackable(room, Record.get_entity("custom_filter_coin"), 10)

      script = run("""
      results = search.match(!custom_filter_room!, "pièce", filter="french_name")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
      assert hd(results).quantity == 10
    end
  end

  # ---------------------------------------------------------------------------
  # Mixed contents: browsing with quantity attribute

  describe "browsing contents" do
    test "all items in contents respond to .quantity" do
      {:ok, room} = Record.create_entity(key: "browse_room")
      {:ok, _sword} = Record.create_entity(key: "browse_sword", location: room)
      Record.set_attribute("browse_sword", "name", "sword")
      {:ok, _coin} = Record.create_entity(key: "browse_coin")
      Record.set_attribute("browse_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("browse_coin"), 75)

      script = run("""
      total = 0
      for item in !browse_room!.contents:
          total = total + item.quantity
      done
      """)

      total = Script.get_variable_value(script, "total")
      # sword has quantity 1, stackable has quantity 75
      assert total == 76
    end
  end
end
