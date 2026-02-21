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
  # search.match — index selection

  describe "search.match — index selection" do
    test "index=1 returns the first matching item" do
      {:ok, room} = Record.create_entity(key: "idx_room")
      {:ok, _coin} = Record.create_entity(key: "idx_gold")
      {:ok, _bar} = Record.create_entity(key: "idx_bar")
      Record.set_attribute("idx_gold", "name", "gold coin")
      Record.set_attribute("idx_bar", "name", "gold bar")
      Record.add_stackable(room, Record.get_entity("idx_gold"), 10)
      Record.add_stackable(room, Record.get_entity("idx_bar"), 5)

      script = run("""
      results = search.match(!idx_room!, "gold", index=1)
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "index=2 returns the second matching item" do
      {:ok, room} = Record.create_entity(key: "idx2_room")
      {:ok, _coin} = Record.create_entity(key: "idx2_gold")
      {:ok, _bar} = Record.create_entity(key: "idx2_bar")
      Record.set_attribute("idx2_gold", "name", "gold coin")
      Record.set_attribute("idx2_bar", "name", "gold bar")
      Record.add_stackable(room, Record.get_entity("idx2_gold"), 10)
      Record.add_stackable(room, Record.get_entity("idx2_bar"), 5)

      script = run("""
      results = search.match(!idx2_room!, "gold", index=2)
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "index out of range returns an empty list" do
      {:ok, room} = Record.create_entity(key: "idx_oor_room")
      {:ok, _coin} = Record.create_entity(key: "idx_oor_coin")
      Record.set_attribute("idx_oor_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("idx_oor_coin"), 10)

      script = run("""
      results = search.match(!idx_oor_room!, "gold", index=99)
      """)

      results = Script.get_variable_value(script, "results")
      assert results == []
    end

    test "index and limit can be combined: select Nth then cap quantity" do
      {:ok, room} = Record.create_entity(key: "idx_lim_room")
      {:ok, player} = Record.create_entity(key: "idx_lim_player")
      {:ok, _coin} = Record.create_entity(key: "idx_lim_coin")
      {:ok, _bar} = Record.create_entity(key: "idx_lim_bar")
      Record.set_attribute("idx_lim_coin", "name", "gold coin")
      Record.set_attribute("idx_lim_bar", "name", "gold bar")
      Record.add_stackable(room, Record.get_entity("idx_lim_coin"), 100)
      Record.add_stackable(room, Record.get_entity("idx_lim_bar"), 200)

      run("""
      matches = search.match(!idx_lim_room!, "gold", index=2, limit=5)
      matches[0].location = !idx_lim_player!
      """)

      bar = Record.get_entity("idx_lim_bar")
      assert Record.get_stackable_quantity(player, bar) == 5
      assert Record.get_stackable_quantity(room, bar) == 195
    end
  end

  # ---------------------------------------------------------------------------
  # search.match — __visible__ hook

  describe "search.match — __visible__ hook" do
    test "items without __visible__ are always included regardless of viewer" do
      {:ok, room} = Record.create_entity(key: "vis_default_room")
      {:ok, _player} = Record.create_entity(key: "vis_default_player")
      {:ok, _coin} = Record.create_entity(key: "vis_default_coin")
      Record.set_attribute("vis_default_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("vis_default_coin"), 10)

      script = run("""
      results = search.match(!vis_default_room!, "gold", viewer=!vis_default_player!)
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "__visible__ returning False hides item from viewer" do
      {:ok, room} = Record.create_entity(key: "vis_hide_room")
      {:ok, _player} = Record.create_entity(key: "vis_hide_player")
      {:ok, _coin} = Record.create_entity(key: "vis_hide_coin")
      Record.set_attribute("vis_hide_coin", "name", "gold coin")
      Record.set_attribute("vis_hide_coin", "stackable", true)
      Record.set_method("vis_hide_coin", "__visible__", [{"viewer", [index: 0, type: :entity]}], "return False")
      Record.add_stackable(room, Record.get_entity("vis_hide_coin"), 10)

      script = run("""
      results = search.match(!vis_hide_room!, "gold", viewer=!vis_hide_player!)
      """)

      results = Script.get_variable_value(script, "results")
      assert results == []
    end

    test "__visible__ returning False does not affect searches without a viewer" do
      {:ok, room} = Record.create_entity(key: "vis_noview_room")
      {:ok, _coin} = Record.create_entity(key: "vis_noview_coin")
      Record.set_attribute("vis_noview_coin", "name", "gold coin")
      Record.set_attribute("vis_noview_coin", "stackable", true)
      Record.set_method("vis_noview_coin", "__visible__", [{"viewer", [index: 0, type: :entity]}], "return False")
      Record.add_stackable(room, Record.get_entity("vis_noview_coin"), 10)

      script = run("""
      results = search.match(!vis_noview_room!, "gold")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "__visible__ returning True keeps item visible" do
      {:ok, room} = Record.create_entity(key: "vis_show_room")
      {:ok, _player} = Record.create_entity(key: "vis_show_player")
      {:ok, _coin} = Record.create_entity(key: "vis_show_coin")
      Record.set_attribute("vis_show_coin", "name", "gold coin")
      Record.set_attribute("vis_show_coin", "stackable", true)
      Record.set_method("vis_show_coin", "__visible__", [{"viewer", [index: 0, type: :entity]}], "return True")
      Record.add_stackable(room, Record.get_entity("vis_show_coin"), 10)

      script = run("""
      results = search.match(!vis_show_room!, "gold", viewer=!vis_show_player!)
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # search.match — __namefor__ hook

  describe "search.match — __namefor__ hook" do
    test "without viewer, matching uses the raw attribute" do
      {:ok, room} = Record.create_entity(key: "nfr_noview_room")
      {:ok, _coin} = Record.create_entity(key: "nfr_noview_coin")
      Record.set_attribute("nfr_noview_coin", "name", "boring name")
      Record.set_attribute("nfr_noview_coin", "stackable", true)
      Record.set_method("nfr_noview_coin", "__namefor__", [{"viewer", [index: 0, type: :entity]}], ~s(return "special name"))
      Record.add_stackable(room, Record.get_entity("nfr_noview_coin"), 5)

      script = run("""
      results = search.match(!nfr_noview_room!, "boring")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "with viewer, matching uses __namefor__ instead of the raw attribute" do
      {:ok, room} = Record.create_entity(key: "nfr_view_room")
      {:ok, _player} = Record.create_entity(key: "nfr_view_player")
      {:ok, _coin} = Record.create_entity(key: "nfr_view_coin")
      Record.set_attribute("nfr_view_coin", "name", "boring name")
      Record.set_attribute("nfr_view_coin", "stackable", true)
      Record.set_method("nfr_view_coin", "__namefor__", [{"viewer", [index: 0, type: :entity]}], ~s(return "special name"))
      Record.add_stackable(room, Record.get_entity("nfr_view_coin"), 5)

      # "special" matches what __namefor__ returns; "boring" does not
      script = run("""
      by_special = search.match(!nfr_view_room!, "special", viewer=!nfr_view_player!)
      by_boring  = search.match(!nfr_view_room!, "boring",  viewer=!nfr_view_player!)
      """)

      by_special = Script.get_variable_value(script, "by_special")
      by_boring = Script.get_variable_value(script, "by_boring")
      assert length(by_special) == 1
      assert by_boring == []
    end

    test "items without __namefor__ fall back to the raw attribute even with a viewer" do
      {:ok, room} = Record.create_entity(key: "nfr_fallback_room")
      {:ok, _player} = Record.create_entity(key: "nfr_fallback_player")
      {:ok, _coin} = Record.create_entity(key: "nfr_fallback_coin")
      Record.set_attribute("nfr_fallback_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("nfr_fallback_coin"), 5)

      script = run("""
      results = search.match(!nfr_fallback_room!, "gold", viewer=!nfr_fallback_player!)
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "__namefor__ returning an f-string is evaluated correctly" do
      # This test verifies that when __namefor__ returns an f-string (e.g.
      # f"[tag] {self.name}"), the f-string is properly evaluated so the
      # resulting plain string is used for matching — not the raw
      # %Format.String{} struct.
      {:ok, room} = Record.create_entity(key: "nfr_fstr_room")
      {:ok, _player} = Record.create_entity(key: "nfr_fstr_player")
      {:ok, _coin} = Record.create_entity(key: "nfr_fstr_coin")
      Record.set_attribute("nfr_fstr_coin", "name", "gold coin")
      Record.set_attribute("nfr_fstr_coin", "stackable", true)
      Record.set_method("nfr_fstr_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return f"[tag] {self.name}"))
      Record.add_stackable(room, Record.get_entity("nfr_fstr_coin"), 3)

      script = run("""
      by_tag   = search.match(!nfr_fstr_room!, "[tag]", viewer=!nfr_fstr_player!)
      by_notag = search.match(!nfr_fstr_room!, "[tag]")
      """)

      by_tag = Script.get_variable_value(script, "by_tag")
      by_notag = Script.get_variable_value(script, "by_notag")
      # With a viewer: __namefor__ returns f"[tag] {self.name}" → "[tag] gold coin" → matches "[tag]"
      assert length(by_tag) == 1
      # Without a viewer: raw "gold coin" used → does not contain "[tag]"
      assert by_notag == []
    end
  end

  # ---------------------------------------------------------------------------
  # search.match — normalize hook on !search! entity

  describe "search.match — normalize hook" do
    test "without !search! entity, default lowercase normalisation applies" do
      {:ok, room} = Record.create_entity(key: "norm_default_room")
      {:ok, _coin} = Record.create_entity(key: "norm_default_coin")
      Record.set_attribute("norm_default_coin", "name", "Gold Coin")
      Record.add_stackable(room, Record.get_entity("norm_default_coin"), 10)

      # lowercase search term matches mixed-case item name via default downcase
      script = run("""
      results = search.match(!norm_default_room!, "gold")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1
    end

    test "!search!.normalize is used for both the search term and each item name" do
      # The normalizer returns a fixed sentinel string for every input.
      # This means any search term will match any item, since both sides
      # normalise to the same value — demonstrating that the hook is invoked
      # for each side of the comparison.
      {:ok, _search_entity} = Record.create_entity(key: "search")
      Record.set_method("search", "normalize", [{"text", [index: 0, type: :str]}], ~s(return "SENTINEL"))

      {:ok, room} = Record.create_entity(key: "norm_hook_room")
      {:ok, _coin} = Record.create_entity(key: "norm_hook_coin")
      Record.set_attribute("norm_hook_coin", "name", "anything")
      Record.add_stackable(room, Record.get_entity("norm_hook_coin"), 7)

      # "SENTINEL" matches because both sides normalise to "SENTINEL"
      script = run("""
      results = search.match(!norm_hook_room!, "SENTINEL")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1

      # clean up the global !search! entity so it doesn't bleed into other tests
      Record.Cache.clear()
    end

    test "!search!.normalize enables accent-insensitive matching" do
      {:ok, _search_entity} = Record.create_entity(key: "search")
      # Normalizer strips a known accent substitution: é -> e, è -> e
      Record.set_method("search", "normalize", [{"text", [index: 0, type: :str]}], """
      result = text.lower()
      result = result.replace("é", "e")
      result = result.replace("è", "e")
      return result
      """)

      {:ok, room} = Record.create_entity(key: "norm_accent_room")
      {:ok, _sword} = Record.create_entity(key: "norm_accent_sword")
      Record.set_attribute("norm_accent_sword", "name", "épée")
      Record.add_stackable(room, Record.get_entity("norm_accent_sword"), 1)

      # "epee" would not match "épée" with plain downcase, but does with the hook
      script = run("""
      results = search.match(!norm_accent_room!, "epee")
      """)

      results = Script.get_variable_value(script, "results")
      assert length(results) == 1

      Record.Cache.clear()
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
