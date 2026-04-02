defmodule Pythelix.Scripting.Namespace.Module.NamesTest do
  @moduledoc """
  Tests for the names module: grouping entities by name for display.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Entity
  alias Pythelix.Record
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.SubEntity

  # Creates a client entity that controls the given character entity.
  # Sets client_id to the entity key so the HubStub can route messages
  # back to `last_msg` on the entity for assertion.
  defp setup_test_client(client_key, character_key) do
    unless Record.get_entity("generic/client") do
      {:ok, _} = Record.create_entity(key: "generic/client", virtual: true)
    end

    parent = Record.get_entity("generic/client")
    {:ok, _} = Record.create_entity(key: client_key, virtual: true, parent: parent)

    entity = Record.get_entity(character_key)
    id_or_key = Entity.get_id_or_key(entity)

    controls_dict = Dict.put(Dict.new(), "__controls", MapSet.new([id_or_key]))
    controls = %SubEntity{base: nil, data: controls_dict}
    Record.set_attribute(client_key, "controls", controls)
    Record.set_attribute(client_key, "client_id", client_key)
  end

  describe "names.group — basic" do
    test "groups entities with the same name into a single entry" do
      {:ok, room} = Record.create_entity(key: "ng_room")
      {:ok, _a1} = Record.create_entity(key: "ng_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_apple2", location: room)
      {:ok, _a3} = Record.create_entity(key: "ng_apple3", location: room)
      Record.set_attribute("ng_apple1", "name", "apple")
      Record.set_attribute("ng_apple2", "name", "apple")
      Record.set_attribute("ng_apple3", "name", "apple")

      script =
        run("""
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

      script =
        run("""
        items = !ng_diff_room!.contents
        result = names.group(items)
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
      assert "sword" in result
      assert "shield" in result
    end

    test "empty list returns an empty list" do
      script =
        run("""
        result = names.group([])
        """)

      result = Script.get_variable_value(script, "result")
      assert result == []
    end
  end

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

      script =
        run("""
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

  describe "names.group — mixed content" do
    test "stackable quantities are summed in the group" do
      {:ok, room} = Record.create_entity(key: "ng_stack_room")
      {:ok, _coin} = Record.create_entity(key: "ng_stack_coin")
      Record.set_attribute("ng_stack_coin", "stackable", true)
      Record.set_attribute("ng_stack_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("ng_stack_coin"), 100)

      script =
        run("""
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

      script =
        run("""
        items = !ng_mix_room!.contents
        result = names.group(items)
        """)

      result = Script.get_variable_value(script, "result")
      assert length(result) == 2
      assert "sword" in result
      assert "gold coin" in result
    end
  end

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

      Record.set_method(
        "ng_nf2_apple1",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code
      )

      Record.set_method(
        "ng_nf2_apple2",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code
      )

      Record.set_method(
        "ng_nf2_apple3",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        namefor_code
      )

      script =
        run("""
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
      Record.set_method(
        "ng_nf1_apple1",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "red apple")
      )

      Record.set_method(
        "ng_nf1_apple2",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "red apple")
      )

      script =
        run("""
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

      Record.set_method(
        "ng_nf_single_sword",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return self.name
        endif
        return f"{quantity} {self.name}s"
        """
      )

      script =
        run("""
        items = !ng_nf_single_room!.contents
        result = names.group(items, viewer=!ng_nf_single_player!)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["sword"]
    end
  end

  describe "names.group — without viewer" do
    test "raw attribute is used when no viewer is provided" do
      {:ok, room} = Record.create_entity(key: "ng_noview_room")
      {:ok, _a1} = Record.create_entity(key: "ng_noview_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_noview_apple2", location: room)
      Record.set_attribute("ng_noview_apple1", "name", "apple")
      Record.set_attribute("ng_noview_apple2", "name", "apple")

      # Even with __namefor__ defined, it should not be called without viewer
      Record.set_method(
        "ng_noview_apple1",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "custom name")
      )

      Record.set_method(
        "ng_noview_apple2",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "custom name")
      )

      script =
        run("""
        items = !ng_noview_room!.contents
        result = names.group(items)
        """)

      result = Script.get_variable_value(script, "result")
      # Without viewer, raw "apple" attribute is used, not "custom name"
      assert result == ["apple"]
    end
  end

  describe "names.group — custom filter" do
    test "groups by a custom attribute when filter is specified" do
      {:ok, room} = Record.create_entity(key: "ng_filter_room")
      {:ok, _a1} = Record.create_entity(key: "ng_filter_sword1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_filter_sword2", location: room)
      Record.set_attribute("ng_filter_sword1", "name", "iron sword")
      Record.set_attribute("ng_filter_sword2", "name", "steel sword")
      Record.set_attribute("ng_filter_sword1", "category", "weapon")
      Record.set_attribute("ng_filter_sword2", "category", "weapon")

      script =
        run("""
        items = !ng_filter_room!.contents
        result = names.group(items, filter="category")
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["weapon"]
    end
  end

  describe "names.group — with search.match output" do
    test "groups search.match results" do
      {:ok, room} = Record.create_entity(key: "ng_sm_room")
      {:ok, _a1} = Record.create_entity(key: "ng_sm_apple1", location: room)
      {:ok, _a2} = Record.create_entity(key: "ng_sm_apple2", location: room)
      {:ok, _sword} = Record.create_entity(key: "ng_sm_sword", location: room)
      Record.set_attribute("ng_sm_apple1", "name", "red apple")
      Record.set_attribute("ng_sm_apple2", "name", "red apple")
      Record.set_attribute("ng_sm_sword", "name", "sword")

      script =
        run("""
        matches = search.match(!ng_sm_room!, "red")
        result = names.group(matches)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["red apple"]
    end
  end

  describe "names.group — stackable quantities" do
    test "stackable quantity is reflected in __namefor__ call" do
      {:ok, room} = Record.create_entity(key: "ng_sqty_room")
      {:ok, _player} = Record.create_entity(key: "ng_sqty_player")
      {:ok, _coin} = Record.create_entity(key: "ng_sqty_coin")
      Record.set_attribute("ng_sqty_coin", "stackable", true)
      Record.set_attribute("ng_sqty_coin", "name", "gold coin")

      Record.set_method(
        "ng_sqty_coin",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "gold coin"
        endif
        return f"{quantity} gold coins"
        """
      )

      Record.add_stackable(room, Record.get_entity("ng_sqty_coin"), 100)

      script =
        run("""
        items = !ng_sqty_room!.contents
        result = names.group(items, viewer=!ng_sqty_player!)
        """)

      result = Script.get_variable_value(script, "result")
      assert result == ["100 gold coins"]
    end
  end

  describe "names.eval" do
    test "returns the name attribute when no __namefor__ is defined" do
      {:ok, _e} = Record.create_entity(key: "ne_entity")
      {:ok, _v} = Record.create_entity(key: "ne_viewer")
      Record.set_attribute("ne_entity", "name", "sword")

      script =
        run_ok("""
        result = names.eval(!ne_entity!, !ne_viewer!)
        """)

      assert Script.get_variable_value(script, "result") == "sword"
    end

    test "calls __namefor__ when defined" do
      {:ok, _e} = Record.create_entity(key: "ne_nf_entity")
      {:ok, _v} = Record.create_entity(key: "ne_nf_viewer")
      Record.set_attribute("ne_nf_entity", "name", "sword")

      Record.set_method(
        "ne_nf_entity",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "custom name")
      )

      script =
        run_ok("""
        result = names.eval(!ne_nf_entity!, !ne_nf_viewer!)
        """)

      assert Script.get_variable_value(script, "result") == "custom name"
    end

    test "passes quantity to __namefor__ when provided" do
      {:ok, _e} = Record.create_entity(key: "ne_qty_entity")
      {:ok, _v} = Record.create_entity(key: "ne_qty_viewer")
      Record.set_attribute("ne_qty_entity", "name", "apple")

      Record.set_method(
        "ne_qty_entity",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return self.name
        endif
        return f"{quantity} {self.name}s"
        """
      )

      script =
        run_ok("""
        result = names.eval(!ne_qty_entity!, !ne_qty_viewer!, quantity=3)
        """)

      assert Script.get_variable_value(script, "result") == "3 apples"
    end
  end

  describe "names.notify" do
    test "sends a plain string message to an entity's controlling client" do
      {:ok, room} = Record.create_entity(key: "nn_room")
      {:ok, _char} = Record.create_entity(key: "nn_char", location: room)
      Record.set_attribute("nn_char", "name", "Alice")
      setup_test_client("nn_client", "nn_char")

      run_ok("""
      names.notify(!nn_char!, "Hello there")
      """)

      assert Record.get_attribute(Record.get_entity("nn_client"), "last_msg") == "Hello there"
    end

    test "resolves entity names in f-strings for the viewer" do
      {:ok, room} = Record.create_entity(key: "nn_fstr_room")
      {:ok, _giver} = Record.create_entity(key: "nn_fstr_giver", location: room)
      {:ok, _receiver} = Record.create_entity(key: "nn_fstr_receiver", location: room)
      Record.set_attribute("nn_fstr_giver", "name", "Alice")
      Record.set_attribute("nn_fstr_receiver", "name", "Bob")
      setup_test_client("nn_fstr_client", "nn_fstr_receiver")

      run_ok("""
      giver = !nn_fstr_giver!
      names.notify(!nn_fstr_receiver!, f"{giver} gives you a sword.")
      """)

      assert Record.get_attribute(Record.get_entity("nn_fstr_client"), "last_msg") ==
               "Alice gives you a sword."
    end

    test "uses __namefor__ for viewer-specific names" do
      {:ok, room} = Record.create_entity(key: "nn_nf_room")
      {:ok, _actor} = Record.create_entity(key: "nn_nf_actor", location: room)
      {:ok, _viewer} = Record.create_entity(key: "nn_nf_viewer", location: room)
      Record.set_attribute("nn_nf_actor", "name", "Alice")

      Record.set_method(
        "nn_nf_actor",
        "__namefor__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return "a mysterious figure")
      )

      setup_test_client("nn_nf_client", "nn_nf_viewer")

      run_ok("""
      actor = !nn_nf_actor!
      names.notify(!nn_nf_viewer!, f"{actor} waves at you.")
      """)

      assert Record.get_attribute(Record.get_entity("nn_nf_client"), "last_msg") ==
               "a mysterious figure waves at you."
    end

    test "does nothing if entity has no controlling client" do
      {:ok, _obj} = Record.create_entity(key: "nn_nomsg_obj")
      Record.set_attribute("nn_nomsg_obj", "name", "rock")

      # Ensure generic/client exists so Clients.active() works
      unless Record.get_entity("generic/client") do
        {:ok, _} = Record.create_entity(key: "generic/client", virtual: true)
      end

      # Should not raise — entity has no controlling client
      run_ok("""
      names.notify(!nn_nomsg_obj!, "Hello")
      """)
    end

    test "skips sending when only_visible and entity is not visible" do
      {:ok, room} = Record.create_entity(key: "nn_vis_room")
      {:ok, _actor} = Record.create_entity(key: "nn_vis_actor", location: room)
      {:ok, _viewer} = Record.create_entity(key: "nn_vis_viewer", location: room)
      Record.set_attribute("nn_vis_actor", "name", "Ghost")

      # Actor is invisible to viewer
      Record.set_method(
        "nn_vis_actor",
        "__visible__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return False)
      )

      setup_test_client("nn_vis_client", "nn_vis_viewer")

      run_ok("""
      actor = !nn_vis_actor!
      names.notify(!nn_vis_viewer!, f"{actor} whispers.")
      """)

      # Message should NOT have been sent
      assert Record.get_attribute(Record.get_entity("nn_vis_client"), "last_msg") == nil
    end

    test "sends when only_visible=False even if entity is not visible" do
      {:ok, room} = Record.create_entity(key: "nn_novis_room")
      {:ok, _actor} = Record.create_entity(key: "nn_novis_actor", location: room)
      {:ok, _viewer} = Record.create_entity(key: "nn_novis_viewer", location: room)
      Record.set_attribute("nn_novis_actor", "name", "Ghost")

      Record.set_method(
        "nn_novis_actor",
        "__visible__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return False)
      )

      setup_test_client("nn_novis_client", "nn_novis_viewer")

      run_ok("""
      actor = !nn_novis_actor!
      names.notify(!nn_novis_viewer!, f"{actor} whispers.", only_visible=False)
      """)

      assert Record.get_attribute(Record.get_entity("nn_novis_client"), "last_msg") ==
               "Ghost whispers."
    end
  end

  describe "names.broadcast" do
    test "sends message to all entities with controlling clients in a location" do
      {:ok, room} = Record.create_entity(key: "nb_room")
      {:ok, _c1} = Record.create_entity(key: "nb_char1", location: room)
      {:ok, _c2} = Record.create_entity(key: "nb_char2", location: room)
      Record.set_attribute("nb_char1", "name", "Alice")
      Record.set_attribute("nb_char2", "name", "Bob")
      setup_test_client("nb_client1", "nb_char1")
      setup_test_client("nb_client2", "nb_char2")

      run_ok("""
      names.broadcast(!nb_room!, "A bell rings.")
      """)

      assert Record.get_attribute(Record.get_entity("nb_client1"), "last_msg") == "A bell rings."
      assert Record.get_attribute(Record.get_entity("nb_client2"), "last_msg") == "A bell rings."
    end

    test "auto-excludes entities referenced in the f-string" do
      {:ok, room} = Record.create_entity(key: "nb_excl_room")
      {:ok, _speaker} = Record.create_entity(key: "nb_excl_speaker", location: room)
      {:ok, _listener} = Record.create_entity(key: "nb_excl_listener", location: room)
      Record.set_attribute("nb_excl_speaker", "name", "Alice")
      Record.set_attribute("nb_excl_listener", "name", "Bob")
      setup_test_client("nb_excl_cl_speaker", "nb_excl_speaker")
      setup_test_client("nb_excl_cl_listener", "nb_excl_listener")

      run_ok("""
      speaker = !nb_excl_speaker!
      names.broadcast(!nb_excl_room!, f"{speaker} says: hello!")
      """)

      # Speaker is auto-excluded, should NOT get the message
      assert Record.get_attribute(Record.get_entity("nb_excl_cl_speaker"), "last_msg") == nil
      # Listener should get the message with speaker's name resolved
      assert Record.get_attribute(Record.get_entity("nb_excl_cl_listener"), "last_msg") ==
               "Alice says: hello!"
    end

    test "does not exclude when auto_exclude=False" do
      {:ok, room} = Record.create_entity(key: "nb_noexcl_room")
      {:ok, _speaker} = Record.create_entity(key: "nb_noexcl_speaker", location: room)
      {:ok, _listener} = Record.create_entity(key: "nb_noexcl_listener", location: room)
      Record.set_attribute("nb_noexcl_speaker", "name", "Alice")
      Record.set_attribute("nb_noexcl_listener", "name", "Bob")
      setup_test_client("nb_noexcl_cl_speaker", "nb_noexcl_speaker")
      setup_test_client("nb_noexcl_cl_listener", "nb_noexcl_listener")

      run_ok("""
      speaker = !nb_noexcl_speaker!
      names.broadcast(!nb_noexcl_room!, f"{speaker} says: hello!", auto_exclude=False)
      """)

      # Both should get the message
      assert Record.get_attribute(Record.get_entity("nb_noexcl_cl_speaker"), "last_msg") != nil
      assert Record.get_attribute(Record.get_entity("nb_noexcl_cl_listener"), "last_msg") != nil
    end

    test "skips entities without controlling clients" do
      {:ok, room} = Record.create_entity(key: "nb_nomsg_room")
      {:ok, _obj} = Record.create_entity(key: "nb_nomsg_obj", location: room)
      {:ok, _char} = Record.create_entity(key: "nb_nomsg_char", location: room)
      Record.set_attribute("nb_nomsg_obj", "name", "rock")
      Record.set_attribute("nb_nomsg_char", "name", "Alice")

      # Only char has a controlling client
      setup_test_client("nb_nomsg_client", "nb_nomsg_char")

      run_ok("""
      names.broadcast(!nb_nomsg_room!, "A bell rings.")
      """)

      # Object has no controlling client, should be unaffected
      assert Record.get_attribute(Record.get_entity("nb_nomsg_obj"), "last_msg") == nil

      assert Record.get_attribute(Record.get_entity("nb_nomsg_client"), "last_msg") ==
               "A bell rings."
    end

    test "uses __namefor__ per viewer in broadcast" do
      {:ok, room} = Record.create_entity(key: "nb_nf_room")
      {:ok, _actor} = Record.create_entity(key: "nb_nf_actor", location: room)
      {:ok, _admin} = Record.create_entity(key: "nb_nf_admin", location: room)
      {:ok, _player} = Record.create_entity(key: "nb_nf_player", location: room)
      Record.set_attribute("nb_nf_actor", "name", "Alice")
      Record.set_attribute("nb_nf_admin", "name", "Admin")
      Record.set_attribute("nb_nf_admin", "is_admin", true)
      Record.set_attribute("nb_nf_player", "name", "Player")

      # Actor is seen differently by admins vs players
      Record.set_method("nb_nf_actor", "__namefor__", [{"viewer", [index: 0, type: :entity]}], """
      if hasattr(viewer, "is_admin") and viewer.is_admin:
          return "Alice (disguised)"
      endif
      return "a masked figure"
      """)

      setup_test_client("nb_nf_cl_admin", "nb_nf_admin")
      setup_test_client("nb_nf_cl_player", "nb_nf_player")

      run_ok("""
      actor = !nb_nf_actor!
      names.broadcast(!nb_nf_room!, f"{actor} waves.")
      """)

      # Admin sees the real name
      assert Record.get_attribute(Record.get_entity("nb_nf_cl_admin"), "last_msg") ==
               "Alice (disguised) waves."

      # Player sees the disguise
      assert Record.get_attribute(Record.get_entity("nb_nf_cl_player"), "last_msg") ==
               "a masked figure waves."
    end

    test "multiple entities in f-string are all excluded" do
      {:ok, room} = Record.create_entity(key: "nb_multi_room")
      {:ok, _giver} = Record.create_entity(key: "nb_multi_giver", location: room)
      {:ok, _receiver} = Record.create_entity(key: "nb_multi_receiver", location: room)
      {:ok, _observer} = Record.create_entity(key: "nb_multi_observer", location: room)
      Record.set_attribute("nb_multi_giver", "name", "Alice")
      Record.set_attribute("nb_multi_receiver", "name", "Bob")
      Record.set_attribute("nb_multi_observer", "name", "Eve")
      setup_test_client("nb_multi_cl_giver", "nb_multi_giver")
      setup_test_client("nb_multi_cl_receiver", "nb_multi_receiver")
      setup_test_client("nb_multi_cl_observer", "nb_multi_observer")

      run_ok("""
      giver = !nb_multi_giver!
      receiver = !nb_multi_receiver!
      names.broadcast(!nb_multi_room!, f"{giver} gives a sword to {receiver}.")
      """)

      # Both giver and receiver are excluded
      assert Record.get_attribute(Record.get_entity("nb_multi_cl_giver"), "last_msg") == nil
      assert Record.get_attribute(Record.get_entity("nb_multi_cl_receiver"), "last_msg") == nil
      # Observer gets the message with both names resolved
      assert Record.get_attribute(Record.get_entity("nb_multi_cl_observer"), "last_msg") ==
               "Alice gives a sword to Bob."
    end

    test "visibility filtering: invisible actor hides message" do
      {:ok, room} = Record.create_entity(key: "nb_invis_room")
      {:ok, _actor} = Record.create_entity(key: "nb_invis_actor", location: room)
      {:ok, _viewer} = Record.create_entity(key: "nb_invis_viewer", location: room)
      Record.set_attribute("nb_invis_actor", "name", "Ghost")
      Record.set_attribute("nb_invis_viewer", "name", "Bob")

      # Actor is invisible to everyone
      Record.set_method(
        "nb_invis_actor",
        "__visible__",
        [{"viewer", [index: 0, type: :entity]}],
        ~s(return False)
      )

      setup_test_client("nb_invis_client", "nb_invis_viewer")

      run_ok("""
      actor = !nb_invis_actor!
      names.broadcast(!nb_invis_room!, f"{actor} appears.")
      """)

      # Viewer can't see actor, so message is not sent
      assert Record.get_attribute(Record.get_entity("nb_invis_client"), "last_msg") == nil
    end

    test "only entities in f-string drive exclusion: unlisted entities always receive" do
      # A, B, C, D all in room R.
      # f-string mentions only B and C.
      # Expected: A and D receive; B and C are excluded.
      {:ok, room} = Record.create_entity(key: "nb_abcd_room")
      {:ok, _a} = Record.create_entity(key: "nb_abcd_a", location: room)
      {:ok, _b} = Record.create_entity(key: "nb_abcd_b", location: room)
      {:ok, _c} = Record.create_entity(key: "nb_abcd_c", location: room)
      {:ok, _d} = Record.create_entity(key: "nb_abcd_d", location: room)

      for key <- ~w(nb_abcd_a nb_abcd_b nb_abcd_c nb_abcd_d) do
        Record.set_attribute(key, "name", key)
      end

      setup_test_client("nb_abcd_cl_a", "nb_abcd_a")
      setup_test_client("nb_abcd_cl_b", "nb_abcd_b")
      setup_test_client("nb_abcd_cl_c", "nb_abcd_c")
      setup_test_client("nb_abcd_cl_d", "nb_abcd_d")

      run_ok("""
      a = !nb_abcd_a!
      b = !nb_abcd_b!
      c = !nb_abcd_c!
      d = !nb_abcd_d!
      names.broadcast(!nb_abcd_room!, f"{b} gives something to {c}.")
      """)

      assert Record.get_attribute(Record.get_entity("nb_abcd_cl_a"), "last_msg") != nil
      assert Record.get_attribute(Record.get_entity("nb_abcd_cl_b"), "last_msg") == nil
      assert Record.get_attribute(Record.get_entity("nb_abcd_cl_c"), "last_msg") == nil
      assert Record.get_attribute(Record.get_entity("nb_abcd_cl_d"), "last_msg") != nil
    end

    test "visibility is per-recipient based on f-string entities, not the recipient's own visibility" do
      # Room has A, B, C. f-string mentions B.
      # B is invisible to C but visible to A.
      # Expected: A receives (can see B); C does not (cannot see B).
      # B is excluded (it's in the f-string).
      # A's own visibility is irrelevant to whether A receives the message.
      {:ok, room} = Record.create_entity(key: "nb_vis2_room")
      {:ok, _a} = Record.create_entity(key: "nb_vis2_a", location: room)
      {:ok, _b} = Record.create_entity(key: "nb_vis2_b", location: room)
      {:ok, _c} = Record.create_entity(key: "nb_vis2_c", location: room)
      Record.set_attribute("nb_vis2_a", "name", "Alice")
      Record.set_attribute("nb_vis2_b", "name", "Bob")
      Record.set_attribute("nb_vis2_c", "name", "Charlie")

      # B is invisible to C only
      Record.set_method(
        "nb_vis2_b",
        "__visible__",
        [{"viewer", [index: 0, type: :entity]}],
        """
        if viewer == !nb_vis2_c!:
            return False
        endif
        return True
        """
      )

      setup_test_client("nb_vis2_cl_a", "nb_vis2_a")
      setup_test_client("nb_vis2_cl_b", "nb_vis2_b")
      setup_test_client("nb_vis2_cl_c", "nb_vis2_c")

      run_ok("""
      b = !nb_vis2_b!
      names.broadcast(!nb_vis2_room!, f"{b} waves.")
      """)

      # A can see B → receives message
      assert Record.get_attribute(Record.get_entity("nb_vis2_cl_a"), "last_msg") == "Bob waves."
      # B is in the f-string → excluded
      assert Record.get_attribute(Record.get_entity("nb_vis2_cl_b"), "last_msg") == nil
      # C cannot see B → does not receive message
      assert Record.get_attribute(Record.get_entity("nb_vis2_cl_c"), "last_msg") == nil
    end
  end
end
