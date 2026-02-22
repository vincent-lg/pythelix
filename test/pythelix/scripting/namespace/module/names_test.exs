defmodule Pythelix.Scripting.Namespace.Module.NamesTest do
  @moduledoc """
  Tests for the names module: grouping entities by name for display.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Record

  # ---------------------------------------------------------------------------
  # Basic grouping

  describe "names.group — basic" do
    test "groups entities with the same name into a single entry" do
      {:ok, room} = Record.create_entity(key: "ng_room")
      {:ok, _a1} = Record.create_entity(key: "ng_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_apple2", location: room)
      {:ok, _a3} = Record.create_entity(key: "ng_apple3", location: room)
      Record.set_attribute("ng_apple1", "name", "apple")
      Record.set_attribute("ng_apple2", "name", "apple")
      Record.set_attribute("ng_apple3", "name", "apple")

      script = run("""
      items = !ng_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["apple"]
    end

    test "different names produce separate entries" do
      {:ok, room} = Record.create_entity(key: "ng_diff_room")
      {:ok, _sword} = Record.create_entity(key: "ng_sword", location: room)
      {:ok, _shield} = Record.create_entity(key: "ng_shield", location: room)
      Record.set_attribute("ng_sword", "name", "sword")
      Record.set_attribute("ng_shield", "name", "shield")

      script = run("""
      items = !ng_diff_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
      assert "sword" in result
      assert "shield" in result
    end

    test "empty list returns an empty list" do
      script = run("""
      result = names.group([])
      """)

      result = Script.get_variable_value(script, "result")
      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # Ordering

  describe "names.group — ordering" do
    test "groups appear in first-occurrence order" do
      {:ok, room} = Record.create_entity(key: "ng_order_room")
      {:ok, _s} = Record.create_entity(key: "ng_order_sword", location: room)
      {:ok, _a1} = Record.create_entity(key: "ng_order_apple1", location: room)
      {:ok, _k} = Record.create_entity(key: "ng_order_key", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_order_apple2", location: room)
      Record.set_attribute("ng_order_sword", "name", "sword")
      Record.set_attribute("ng_order_apple1", "name", "apple")
      Record.set_attribute("ng_order_key", "name", "key")
      Record.set_attribute("ng_order_apple2", "name", "apple")

      script = run("""
      items = !ng_order_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      # sword first, apple second (first occurrence), key third
      # apple2 merges into the apple group at position 2
      assert length(result) == 3
      assert Enum.at(result, 0) == "sword"
      assert Enum.at(result, 1) == "apple"
      assert Enum.at(result, 2) == "key"
    end
  end

  # ---------------------------------------------------------------------------
  # Mixed content: regular entities + stackables

  describe "names.group — mixed content" do
    test "stackable quantities are summed in the group" do
      {:ok, room} = Record.create_entity(key: "ng_stack_room")
      {:ok, _coin} = Record.create_entity(key: "ng_stack_coin")
      Record.set_attribute("ng_stack_coin", "stackable", true)
      Record.set_attribute("ng_stack_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("ng_stack_coin"), 100)

      script = run("""
      items = !ng_stack_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["gold coin"]
    end

    test "regular entities and stackables with different names produce separate groups" do
      {:ok, room} = Record.create_entity(key: "ng_mix_room")
      {:ok, _sword} = Record.create_entity(key: "ng_mix_sword", location: room)
      Record.set_attribute("ng_mix_sword", "name", "sword")
      {:ok, _coin} = Record.create_entity(key: "ng_mix_coin")
      Record.set_attribute("ng_mix_coin", "stackable", true)
      Record.set_attribute("ng_mix_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("ng_mix_coin"), 50)

      script = run("""
      items = !ng_mix_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
      assert "sword" in result
      assert "gold coin" in result
    end
  end

  # ---------------------------------------------------------------------------
  # __namefor__ with quantity

  describe "names.group — __namefor__ with quantity" do
    test "__namefor__(viewer, quantity) is called when the method accepts 2 args" do
      {:ok, room} = Record.create_entity(key: "ng_nf2_room")
      {:ok, _player} = Record.create_entity(key: "ng_nf2_player")
      {:ok, _a1} = Record.create_entity(key: "ng_nf2_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_nf2_apple2", location: room)
      {:ok, _a3} = Record.create_entity(key: "ng_nf2_apple3", location: room)
      Record.set_attribute("ng_nf2_apple1", "name", "apple")
      Record.set_attribute("ng_nf2_apple2", "name", "apple")
      Record.set_attribute("ng_nf2_apple3", "name", "apple")

      # __namefor__ with 2 args: returns plural form with quantity
      namefor_code = """
      if quantity == 1:
          return self.name
      endif
      return f"{quantity} {self.name}s"
      """
      Record.set_method("ng_nf2_apple1", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code)
      Record.set_method("ng_nf2_apple2", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code)
      Record.set_method("ng_nf2_apple3", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code)

      script = run("""
      items = !ng_nf2_room!.contents
      result = names.group(items, viewer=!ng_nf2_player!)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["3 apples"]
    end

    test "__namefor__(viewer) with 1 arg still works (quantity not passed)" do
      {:ok, room} = Record.create_entity(key: "ng_nf1_room")
      {:ok, _player} = Record.create_entity(key: "ng_nf1_player")
      {:ok, _a1} = Record.create_entity(key: "ng_nf1_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_nf1_apple2", location: room)
      Record.set_attribute("ng_nf1_apple1", "name", "apple")
      Record.set_attribute("ng_nf1_apple2", "name", "apple")

      # __namefor__ with only 1 arg: returns a custom name
      Record.set_method("ng_nf1_apple1", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "red apple"))
      Record.set_method("ng_nf1_apple2", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "red apple"))

      script = run("""
      items = !ng_nf1_room!.contents
      result = names.group(items, viewer=!ng_nf1_player!)
      """)

      result = Script.get_variable_value(script, "result")
      # Both apples have __namefor__ returning "red apple" with 1 arg.
      # Since the method only accepts 1 arg, call_namefor/3 calls with [viewer] only.
      # The display name is "red apple" (same as singular, no quantity formatting).
      assert result == ["red apple"]
    end

    test "single item with __namefor__(viewer, quantity) gets quantity 1" do
      {:ok, room} = Record.create_entity(key: "ng_nf_single_room")
      {:ok, _player} = Record.create_entity(key: "ng_nf_single_player")
      {:ok, _sword} = Record.create_entity(key: "ng_nf_single_sword", location: room)
      Record.set_attribute("ng_nf_single_sword", "name", "sword")
      Record.set_method("ng_nf_single_sword", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return self.name
        endif
        return f"{quantity} {self.name}s"
        """)

      script = run("""
      items = !ng_nf_single_room!.contents
      result = names.group(items, viewer=!ng_nf_single_player!)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["sword"]
    end
  end

  # ---------------------------------------------------------------------------
  # Without viewer

  describe "names.group — without viewer" do
    test "raw attribute is used when no viewer is provided" do
      {:ok, room} = Record.create_entity(key: "ng_noview_room")
      {:ok, _a1} = Record.create_entity(key: "ng_noview_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_noview_apple2", location: room)
      Record.set_attribute("ng_noview_apple1", "name", "apple")
      Record.set_attribute("ng_noview_apple2", "name", "apple")

      # Even with __namefor__ defined, it should not be called without viewer
      Record.set_method("ng_noview_apple1", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "custom name"))
      Record.set_method("ng_noview_apple2", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "custom name"))

      script = run("""
      items = !ng_noview_room!.contents
      result = names.group(items)
      """)

      result = Script.get_variable_value(script, "result")
      # Without viewer, raw "apple" attribute is used, not "custom name"
      assert result == ["apple"]
    end
  end

  # ---------------------------------------------------------------------------
  # Custom filter attribute

  describe "names.group — custom filter" do
    test "groups by a custom attribute when filter is specified" do
      {:ok, room} = Record.create_entity(key: "ng_filter_room")
      {:ok, _a1} = Record.create_entity(key: "ng_filter_sword1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_filter_sword2", location: room)
      Record.set_attribute("ng_filter_sword1", "name", "iron sword")
      Record.set_attribute("ng_filter_sword2", "name", "steel sword")
      Record.set_attribute("ng_filter_sword1", "category", "weapon")
      Record.set_attribute("ng_filter_sword2", "category", "weapon")

      script = run("""
      items = !ng_filter_room!.contents
      result = names.group(items, filter="category")
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["weapon"]
    end
  end

  # ---------------------------------------------------------------------------
  # Works with search.match output

  describe "names.group — with search.match output" do
    test "groups search.match results" do
      {:ok, room} = Record.create_entity(key: "ng_sm_room")
      {:ok, _a1} = Record.create_entity(key: "ng_sm_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_sm_apple2", location: room)
      {:ok, _sword} = Record.create_entity(key: "ng_sm_sword", location: room)
      Record.set_attribute("ng_sm_apple1", "name", "red apple")
      Record.set_attribute("ng_sm_apple2", "name", "red apple")
      Record.set_attribute("ng_sm_sword", "name", "sword")

      script = run("""
      matches = search.match(!ng_sm_room!, "red")
      result = names.group(matches)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["red apple"]
    end
  end

  # ---------------------------------------------------------------------------
  # Stackable quantity summing

  describe "names.group — stackable quantities" do
    test "stackable quantity is reflected in __namefor__ call" do
      {:ok, room} = Record.create_entity(key: "ng_sqty_room")
      {:ok, _player} = Record.create_entity(key: "ng_sqty_player")
      {:ok, _coin} = Record.create_entity(key: "ng_sqty_coin")
      Record.set_attribute("ng_sqty_coin", "stackable", true)
      Record.set_attribute("ng_sqty_coin", "name", "gold coin")
      Record.set_method("ng_sqty_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("ng_sqty_coin"), 100)

      script = run("""
      items = !ng_sqty_room!.contents
      result = names.group(items, viewer=!ng_sqty_player!)
      """)

      result = Script.get_variable_value(script, "result")
      assert result == ["100 gold coins"]
    end
  end
end
