defmodule Pythelix.Command.GetCommandTest do
  @moduledoc """
  Tests for the "get" command processing pattern:
    search.match → location assignment → names.group display.

  Exercises the complete pipeline described in the documented get command,
  including search with limit, location transfer, and grouped display output.
  Covers regular entities, stackables, mixed contents, and edge cases.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Record

  # Helper: define __namefor__ on an entity for pluralized display names.
  defp setup_namefor(entity_key) do
    Record.set_method(entity_key, "__namefor__",
      [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
      """
      if quantity == 1:
          return f"a {self.name}"
      endif
      return f"{quantity} {self.name}s"
      """)
  end

  # ---------------------------------------------------------------------------
  # Search and move: regular entities

  describe "get command — regular entities" do
    test "finds and moves a single entity to character" do
      {:ok, room} = Record.create_entity(key: "gc_re_room")
      {:ok, character} = Record.create_entity(key: "gc_re_char")
      {:ok, _apple} = Record.create_entity(key: "gc_re_apple", location: room)
      Record.set_attribute("gc_re_apple", "name", "apple")

      run("""
      to_pick = search.match(!gc_re_room!, "apple")
      for item in to_pick:
          item.location = !gc_re_char!
      done
      """)

      assert Record.get_contained(character) != []
      assert Record.get_contained(room) == []
    end

    test "finds and moves multiple same-name entities" do
      {:ok, room} = Record.create_entity(key: "gc_multi_room")
      {:ok, character} = Record.create_entity(key: "gc_multi_char")
      {:ok, _a1} = Record.create_entity(key: "gc_multi_a1", location: room)
      {:ok, _a2} = Record.create_entity(key: "gc_multi_a2", location: room)
      {:ok, _a3} = Record.create_entity(key: "gc_multi_a3", location: room)
      Record.set_attribute("gc_multi_a1", "name", "apple")
      Record.set_attribute("gc_multi_a2", "name", "apple")
      Record.set_attribute("gc_multi_a3", "name", "apple")

      run("""
      to_pick = search.match(!gc_multi_room!, "apple")
      for item in to_pick:
          item.location = !gc_multi_char!
      done
      """)

      assert length(Record.get_contained(character)) == 3
      assert Record.get_contained(room) == []
    end

    test "search returns empty when nothing matches" do
      {:ok, _room} = Record.create_entity(key: "gc_nomatch_room")
      {:ok, _apple} = Record.create_entity(
        key: "gc_nomatch_apple",
        location: Record.get_entity("gc_nomatch_room"))
      Record.set_attribute("gc_nomatch_apple", "name", "apple")

      script = run("""
      to_pick = search.match(!gc_nomatch_room!, "banana")
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert to_pick == []
    end

    test "only matching entities are moved, others stay" do
      {:ok, room} = Record.create_entity(key: "gc_selective_room")
      {:ok, character} = Record.create_entity(key: "gc_selective_char")
      {:ok, _apple} = Record.create_entity(key: "gc_selective_apple", location: room)
      {:ok, _sword} = Record.create_entity(key: "gc_selective_sword", location: room)
      Record.set_attribute("gc_selective_apple", "name", "apple")
      Record.set_attribute("gc_selective_sword", "name", "sword")

      run("""
      to_pick = search.match(!gc_selective_room!, "apple")
      for item in to_pick:
          item.location = !gc_selective_char!
      done
      """)

      assert length(Record.get_contained(character)) == 1
      assert length(Record.get_contained(room)) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Search and move: stackables

  describe "get command — stackables" do
    test "finds and moves full stackable quantity" do
      {:ok, room} = Record.create_entity(key: "gc_st_room")
      {:ok, character} = Record.create_entity(key: "gc_st_char")
      {:ok, _coin} = Record.create_entity(key: "gc_st_coin")
      Record.set_attribute("gc_st_coin", "stackable", true)
      Record.set_attribute("gc_st_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("gc_st_coin"), 100)

      run("""
      to_pick = search.match(!gc_st_room!, "gold")
      for item in to_pick:
          item.location = !gc_st_char!
      done
      """)

      coin = Record.get_entity("gc_st_coin")
      assert Record.get_stackable_quantity(room, coin) == 0
      assert Record.get_stackable_quantity(character, coin) == 100
    end

    test "partial transfer with limit" do
      {:ok, room} = Record.create_entity(key: "gc_partial_room")
      {:ok, character} = Record.create_entity(key: "gc_partial_char")
      {:ok, _coin} = Record.create_entity(key: "gc_partial_coin")
      Record.set_attribute("gc_partial_coin", "stackable", true)
      Record.set_attribute("gc_partial_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("gc_partial_coin"), 500)

      run("""
      to_pick = search.match(!gc_partial_room!, "gold", limit=50)
      for item in to_pick:
          item.location = !gc_partial_char!
      done
      """)

      coin = Record.get_entity("gc_partial_coin")
      assert Record.get_stackable_quantity(room, coin) == 450
      assert Record.get_stackable_quantity(character, coin) == 50
    end

    test "limit exceeding available quantity takes all" do
      {:ok, room} = Record.create_entity(key: "gc_over_room")
      {:ok, character} = Record.create_entity(key: "gc_over_char")
      {:ok, _coin} = Record.create_entity(key: "gc_over_coin")
      Record.set_attribute("gc_over_coin", "stackable", true)
      Record.set_attribute("gc_over_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("gc_over_coin"), 5)

      run("""
      to_pick = search.match(!gc_over_room!, "gold", limit=100)
      for item in to_pick:
          item.location = !gc_over_char!
      done
      """)

      coin = Record.get_entity("gc_over_coin")
      assert Record.get_stackable_quantity(room, coin) == 0
      assert Record.get_stackable_quantity(character, coin) == 5
    end

    test "multiple different stackables matching the same search" do
      {:ok, room} = Record.create_entity(key: "gc_multi_st_room")
      {:ok, character} = Record.create_entity(key: "gc_multi_st_char")

      {:ok, _ra} = Record.create_entity(key: "gc_multi_st_ra")
      Record.set_attribute("gc_multi_st_ra", "stackable", true)
      Record.set_attribute("gc_multi_st_ra", "name", "red apple")
      Record.add_stackable(room, Record.get_entity("gc_multi_st_ra"), 5)

      {:ok, _ga} = Record.create_entity(key: "gc_multi_st_ga")
      Record.set_attribute("gc_multi_st_ga", "stackable", true)
      Record.set_attribute("gc_multi_st_ga", "name", "green apple")
      Record.add_stackable(room, Record.get_entity("gc_multi_st_ga"), 3)

      run("""
      to_pick = search.match(!gc_multi_st_room!, "apple")
      for item in to_pick:
          item.location = !gc_multi_st_char!
      done
      """)

      ra = Record.get_entity("gc_multi_st_ra")
      ga = Record.get_entity("gc_multi_st_ga")
      assert Record.get_stackable_quantity(room, ra) == 0
      assert Record.get_stackable_quantity(character, ra) == 5
      assert Record.get_stackable_quantity(room, ga) == 0
      assert Record.get_stackable_quantity(character, ga) == 3
    end

    test "limit is a global budget across all stacks" do
      {:ok, room} = Record.create_entity(key: "gc_limst_room")
      {:ok, character} = Record.create_entity(key: "gc_limst_char")

      # ra added first, ga added second — budget consumed in insertion order
      {:ok, _ra} = Record.create_entity(key: "gc_limst_ra")
      Record.set_attribute("gc_limst_ra", "stackable", true)
      Record.set_attribute("gc_limst_ra", "name", "red apple")
      Record.add_stackable(room, Record.get_entity("gc_limst_ra"), 10)

      {:ok, _ga} = Record.create_entity(key: "gc_limst_ga")
      Record.set_attribute("gc_limst_ga", "stackable", true)
      Record.set_attribute("gc_limst_ga", "name", "green apple")
      Record.add_stackable(room, Record.get_entity("gc_limst_ga"), 8)

      run("""
      to_pick = search.match(!gc_limst_room!, "apple", limit=5)
      for item in to_pick:
          item.location = !gc_limst_char!
      done
      """)

      ra = Record.get_entity("gc_limst_ra")
      ga = Record.get_entity("gc_limst_ga")
      # Budget=5: ra (qty=10) consumes all 5, ga gets nothing
      assert Record.get_stackable_quantity(character, ra) == 5
      assert Record.get_stackable_quantity(room, ra) == 5
      assert Record.get_stackable_quantity(character, ga) == 0
      assert Record.get_stackable_quantity(room, ga) == 8
    end
  end

  # ---------------------------------------------------------------------------
  # Mixed regular entities + stackables

  describe "get command — mixed content" do
    test "search finds both regular entities and stackables" do
      {:ok, room} = Record.create_entity(key: "gc_mix_room")
      {:ok, character} = Record.create_entity(key: "gc_mix_char")

      {:ok, sword} = Record.create_entity(key: "gc_mix_sword", location: room)
      Record.set_attribute("gc_mix_sword", "name", "golden sword")

      {:ok, _coin} = Record.create_entity(key: "gc_mix_coin")
      Record.set_attribute("gc_mix_coin", "stackable", true)
      Record.set_attribute("gc_mix_coin", "name", "gold coin")
      Record.add_stackable(room, Record.get_entity("gc_mix_coin"), 20)

      script = run("""
      to_pick = search.match(!gc_mix_room!, "gold")
      for item in to_pick:
          item.location = !gc_mix_char!
      done
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert length(to_pick) == 2

      coin = Record.get_entity("gc_mix_coin")
      assert Record.get_stackable_quantity(character, coin) == 20
      assert Record.get_location(sword) == character
    end
  end

  # ---------------------------------------------------------------------------
  # Display with names.group

  describe "get command — display with names.group" do
    test "groups same-name regular entities" do
      {:ok, room} = Record.create_entity(key: "gc_disp_room")
      {:ok, _a1} = Record.create_entity(key: "gc_disp_a1", location: room)
      {:ok, _a2} = Record.create_entity(key: "gc_disp_a2", location: room)
      Record.set_attribute("gc_disp_a1", "name", "apple")
      Record.set_attribute("gc_disp_a2", "name", "apple")

      script = run("""
      to_pick = search.match(!gc_disp_room!, "apple")
      display = names.group(to_pick)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["apple"]
    end

    test "pluralized display with __namefor__ and viewer" do
      {:ok, room} = Record.create_entity(key: "gc_plural_room")
      {:ok, _viewer} = Record.create_entity(key: "gc_plural_viewer")
      {:ok, _a1} = Record.create_entity(key: "gc_plural_a1", location: room)
      {:ok, _a2} = Record.create_entity(key: "gc_plural_a2", location: room)
      {:ok, _a3} = Record.create_entity(key: "gc_plural_a3", location: room)
      Record.set_attribute("gc_plural_a1", "name", "apple")
      Record.set_attribute("gc_plural_a2", "name", "apple")
      Record.set_attribute("gc_plural_a3", "name", "apple")

      for key <- ~w(gc_plural_a1 gc_plural_a2 gc_plural_a3) do
        setup_namefor(key)
      end

      script = run("""
      to_pick = search.match(!gc_plural_room!, "apple")
      display = names.group(to_pick, viewer=!gc_plural_viewer!)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["3 apples"]
    end

    test "different-name items produce separate display groups" do
      {:ok, room} = Record.create_entity(key: "gc_diffdisp_room")
      {:ok, _viewer} = Record.create_entity(key: "gc_diffdisp_viewer")

      {:ok, _ra1} = Record.create_entity(key: "gc_diffdisp_ra1", location: room)
      {:ok, _ra2} = Record.create_entity(key: "gc_diffdisp_ra2", location: room)
      {:ok, _ga1} = Record.create_entity(key: "gc_diffdisp_ga1", location: room)
      Record.set_attribute("gc_diffdisp_ra1", "name", "red apple")
      Record.set_attribute("gc_diffdisp_ra2", "name", "red apple")
      Record.set_attribute("gc_diffdisp_ga1", "name", "green apple")

      for key <- ~w(gc_diffdisp_ra1 gc_diffdisp_ra2 gc_diffdisp_ga1) do
        setup_namefor(key)
      end

      script = run("""
      to_pick = search.match(!gc_diffdisp_room!, "apple")
      display = names.group(to_pick, viewer=!gc_diffdisp_viewer!)
      """)

      display = Script.get_variable_value(script, "display")
      assert length(display) == 2
      assert "2 red apples" in display
      assert "a green apple" in display
    end

    test "stackable quantity reflected in display" do
      {:ok, room} = Record.create_entity(key: "gc_stdisp_room")
      {:ok, _viewer} = Record.create_entity(key: "gc_stdisp_viewer")
      {:ok, _coin} = Record.create_entity(key: "gc_stdisp_coin")
      Record.set_attribute("gc_stdisp_coin", "stackable", true)
      Record.set_attribute("gc_stdisp_coin", "name", "gold coin")
      Record.set_method("gc_stdisp_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("gc_stdisp_coin"), 100)

      script = run("""
      to_pick = search.match(!gc_stdisp_room!, "gold")
      display = names.group(to_pick, viewer=!gc_stdisp_viewer!)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["100 gold coins"]
    end

    test "limited stackable quantity reflected in display" do
      {:ok, room} = Record.create_entity(key: "gc_limdisp_room")
      {:ok, _viewer} = Record.create_entity(key: "gc_limdisp_viewer")
      {:ok, _coin} = Record.create_entity(key: "gc_limdisp_coin")
      Record.set_attribute("gc_limdisp_coin", "stackable", true)
      Record.set_attribute("gc_limdisp_coin", "name", "gold coin")
      Record.set_method("gc_limdisp_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("gc_limdisp_coin"), 200)

      script = run("""
      to_pick = search.match(!gc_limdisp_room!, "gold", limit=30)
      display = names.group(to_pick, viewer=!gc_limdisp_viewer!)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["30 gold coins"]
    end
  end

  # ---------------------------------------------------------------------------
  # Full pipeline: search → move → display

  describe "get command — full pipeline" do
    test "search, move, and display regular entities" do
      {:ok, room} = Record.create_entity(key: "gc_full_room")
      {:ok, _character} = Record.create_entity(key: "gc_full_char")

      {:ok, _a1} = Record.create_entity(key: "gc_full_a1", location: room)
      {:ok, _a2} = Record.create_entity(key: "gc_full_a2", location: room)
      Record.set_attribute("gc_full_a1", "name", "apple")
      Record.set_attribute("gc_full_a2", "name", "apple")

      for key <- ~w(gc_full_a1 gc_full_a2) do
        setup_namefor(key)
      end

      script = run("""
      character = !gc_full_char!
      to_pick = search.match(!gc_full_room!, "apple")
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["2 apples"]

      character = Record.get_entity("gc_full_char")
      assert length(Record.get_contained(character)) == 2
      assert Record.get_contained(room) == []
    end

    test "search, move, and display stackables with limit" do
      {:ok, room} = Record.create_entity(key: "gc_fullst_room")
      {:ok, _character} = Record.create_entity(key: "gc_fullst_char")
      {:ok, _coin} = Record.create_entity(key: "gc_fullst_coin")
      Record.set_attribute("gc_fullst_coin", "stackable", true)
      Record.set_attribute("gc_fullst_coin", "name", "gold coin")
      Record.set_method("gc_fullst_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("gc_fullst_coin"), 200)

      script = run("""
      character = !gc_fullst_char!
      to_pick = search.match(!gc_fullst_room!, "gold", limit=30)
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["30 gold coins"]

      coin = Record.get_entity("gc_fullst_coin")
      character = Record.get_entity("gc_fullst_char")
      assert Record.get_stackable_quantity(room, coin) == 170
      assert Record.get_stackable_quantity(character, coin) == 30
    end

    test "no match: search returns empty list" do
      {:ok, _room} = Record.create_entity(key: "gc_noresult_room")

      script = run("""
      to_pick = search.match(!gc_noresult_room!, "sword")
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert to_pick == []
    end

    test "full pipeline with mixed regular entities and stackables" do
      {:ok, room} = Record.create_entity(key: "gc_fullmix_room")
      {:ok, _character} = Record.create_entity(key: "gc_fullmix_char")

      {:ok, _sword} = Record.create_entity(key: "gc_fullmix_sword", location: room)
      Record.set_attribute("gc_fullmix_sword", "name", "golden sword")
      setup_namefor("gc_fullmix_sword")

      {:ok, _coin} = Record.create_entity(key: "gc_fullmix_coin")
      Record.set_attribute("gc_fullmix_coin", "stackable", true)
      Record.set_attribute("gc_fullmix_coin", "name", "gold coin")
      Record.set_method("gc_fullmix_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("gc_fullmix_coin"), 50)

      script = run("""
      character = !gc_fullmix_char!
      to_pick = search.match(!gc_fullmix_room!, "gold")
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      assert length(display) == 2
      assert "a golden sword" in display
      assert "50 gold coins" in display
    end

    test "multiple different stackables: search, move, and display" do
      {:ok, room} = Record.create_entity(key: "gc_diffst_room")
      {:ok, _character} = Record.create_entity(key: "gc_diffst_char")

      {:ok, _ra} = Record.create_entity(key: "gc_diffst_ra")
      Record.set_attribute("gc_diffst_ra", "stackable", true)
      Record.set_attribute("gc_diffst_ra", "name", "red apple")
      Record.set_method("gc_diffst_ra", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a red apple"
        endif
        return f"{quantity} red apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_diffst_ra"), 5)

      {:ok, _ga} = Record.create_entity(key: "gc_diffst_ga")
      Record.set_attribute("gc_diffst_ga", "stackable", true)
      Record.set_attribute("gc_diffst_ga", "name", "green apple")
      Record.set_method("gc_diffst_ga", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a green apple"
        endif
        return f"{quantity} green apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_diffst_ga"), 3)

      script = run("""
      character = !gc_diffst_char!
      to_pick = search.match(!gc_diffst_room!, "apple")
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      assert length(display) == 2
      assert "5 red apples" in display
      assert "3 green apples" in display

      ra = Record.get_entity("gc_diffst_ra")
      ga = Record.get_entity("gc_diffst_ga")
      character = Record.get_entity("gc_diffst_char")
      assert Record.get_stackable_quantity(room, ra) == 0
      assert Record.get_stackable_quantity(character, ra) == 5
      assert Record.get_stackable_quantity(room, ga) == 0
      assert Record.get_stackable_quantity(character, ga) == 3
    end

    test "limit is global: smaller first stack leaves remaining budget for next" do
      {:ok, room} = Record.create_entity(key: "gc_limdiff_room")
      {:ok, _character} = Record.create_entity(key: "gc_limdiff_char")

      # ra (qty=2) added first, ga (qty=10) added second
      {:ok, _ra} = Record.create_entity(key: "gc_limdiff_ra")
      Record.set_attribute("gc_limdiff_ra", "stackable", true)
      Record.set_attribute("gc_limdiff_ra", "name", "red apple")
      Record.set_method("gc_limdiff_ra", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a red apple"
        endif
        return f"{quantity} red apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_limdiff_ra"), 2)

      {:ok, _ga} = Record.create_entity(key: "gc_limdiff_ga")
      Record.set_attribute("gc_limdiff_ga", "stackable", true)
      Record.set_attribute("gc_limdiff_ga", "name", "green apple")
      Record.set_method("gc_limdiff_ga", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a green apple"
        endif
        return f"{quantity} green apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_limdiff_ga"), 10)

      script = run("""
      character = !gc_limdiff_char!
      to_pick = search.match(!gc_limdiff_room!, "apple", limit=3)
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      # Budget=3: ra (qty=2) consumes 2, ga gets remaining 1 → total 3
      assert length(display) == 2
      assert "2 red apples" in display
      assert "a green apple" in display

      ra = Record.get_entity("gc_limdiff_ra")
      ga = Record.get_entity("gc_limdiff_ga")
      character = Record.get_entity("gc_limdiff_char")
      assert Record.get_stackable_quantity(character, ra) == 2
      assert Record.get_stackable_quantity(room, ra) == 0
      assert Record.get_stackable_quantity(character, ga) == 1
      assert Record.get_stackable_quantity(room, ga) == 9
    end
  end

  # ---------------------------------------------------------------------------
  # User's example: 2 red apples + 3 green apples, "get 3 apple"

  describe "get command — documented example" do
    test "character.location used as search container" do
      {:ok, room} = Record.create_entity(key: "gc_loc_room")
      {:ok, _character} = Record.create_entity(key: "gc_loc_char", location: room)
      {:ok, _apple} = Record.create_entity(key: "gc_loc_apple", location: room)
      Record.set_attribute("gc_loc_apple", "name", "apple")

      script = run("""
      character = !gc_loc_char!
      to_pick = search.match(character.location, "apple")
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert length(to_pick) == 1
    end

    test "2 red apples and 3 green apples, get 3 apple" do
      {:ok, room} = Record.create_entity(key: "gc_ex_room")
      {:ok, _character} = Record.create_entity(key: "gc_ex_char", location: room)

      # ra added first — budget consumed in insertion order
      {:ok, _ra} = Record.create_entity(key: "gc_ex_ra")
      Record.set_attribute("gc_ex_ra", "stackable", true)
      Record.set_attribute("gc_ex_ra", "name", "red apple")
      Record.set_method("gc_ex_ra", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a red apple"
        endif
        return f"{quantity} red apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_ex_ra"), 2)

      {:ok, _ga} = Record.create_entity(key: "gc_ex_ga")
      Record.set_attribute("gc_ex_ga", "stackable", true)
      Record.set_attribute("gc_ex_ga", "name", "green apple")
      Record.set_method("gc_ex_ga", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a green apple"
        endif
        return f"{quantity} green apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_ex_ga"), 3)

      script = run("""
      character = !gc_ex_char!
      object = "apple"
      number = 3
      to_pick = search.match(character.location, object, limit=number)
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      display = Script.get_variable_value(script, "display")

      # Global budget=3: 2 red (consumes 2) + 1 green (consumes 1) = 3 total
      # Matches the documented example: "You pick up 2 red apples. You pick up a green apple."
      assert length(to_pick) == 2
      assert length(display) == 2
      assert "2 red apples" in display
      assert "a green apple" in display

      ra = Record.get_entity("gc_ex_ra")
      ga = Record.get_entity("gc_ex_ga")
      character = Record.get_entity("gc_ex_char")
      assert Record.get_stackable_quantity(character, ra) == 2
      assert Record.get_stackable_quantity(character, ga) == 1
      assert Record.get_stackable_quantity(room, ga) == 2
    end

    test "limit=1 picks exactly one item total (first matching stack)" do
      {:ok, room} = Record.create_entity(key: "gc_ex1_room")
      {:ok, _character} = Record.create_entity(key: "gc_ex1_char", location: room)

      # ra added first — with limit=1 total budget, only 1 item from ra is taken
      {:ok, _ra} = Record.create_entity(key: "gc_ex1_ra")
      Record.set_attribute("gc_ex1_ra", "stackable", true)
      Record.set_attribute("gc_ex1_ra", "name", "red apple")
      Record.set_method("gc_ex1_ra", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a red apple"
        endif
        return f"{quantity} red apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_ex1_ra"), 5)

      {:ok, _ga} = Record.create_entity(key: "gc_ex1_ga")
      Record.set_attribute("gc_ex1_ga", "stackable", true)
      Record.set_attribute("gc_ex1_ga", "name", "green apple")
      Record.set_method("gc_ex1_ga", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a green apple"
        endif
        return f"{quantity} green apples"
        """)
      Record.add_stackable(room, Record.get_entity("gc_ex1_ga"), 3)

      script = run("""
      character = !gc_ex1_char!
      to_pick = search.match(character.location, "apple", limit=1)
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      # Budget=1: ra (qty=5) consumes all 1, ga gets nothing
      assert display == ["a red apple"]

      ra = Record.get_entity("gc_ex1_ra")
      ga = Record.get_entity("gc_ex1_ga")
      character = Record.get_entity("gc_ex1_char")
      assert Record.get_stackable_quantity(character, ra) == 1
      assert Record.get_stackable_quantity(room, ra) == 4
      assert Record.get_stackable_quantity(character, ga) == 0
      assert Record.get_stackable_quantity(room, ga) == 3
    end

    test "not found: search returns empty, check via Elixir assertion" do
      {:ok, room} = Record.create_entity(key: "gc_exnf_room")
      {:ok, _character} = Record.create_entity(key: "gc_exnf_char", location: room)

      {:ok, _apple} = Record.create_entity(key: "gc_exnf_apple")
      Record.set_attribute("gc_exnf_apple", "stackable", true)
      Record.set_attribute("gc_exnf_apple", "name", "apple")
      Record.add_stackable(room, Record.get_entity("gc_exnf_apple"), 10)

      script = run("""
      character = !gc_exnf_char!
      object = "banana"
      number = 1
      to_pick = search.match(character.location, object, limit=number)
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert to_pick == []
    end

    test "empty list truthiness: not [] is false in Pythello (Elixir semantics)" do
      # In Pythello, empty lists follow Elixir truthiness rules:
      # [] is truthy, so `not []` is false.
      # The documented `if not to_pick:` pattern needs adjustment
      # to work as intended (e.g., checking length or using == []).
      # Create the room first
      {:ok, _room} = Record.create_entity(key: "gc_truth_room")

      script = run("""
      to_pick = []
      result = not to_pick
      """)

      result = Script.get_variable_value(script, "result")
      # In Pythello (Elixir semantics): not [] == false ([] is truthy)
      assert result == false
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases

  describe "get command — edge cases" do
    test "searching an empty container returns empty list" do
      {:ok, _room} = Record.create_entity(key: "gc_edge_empty_room")

      script = run("""
      to_pick = search.match(!gc_edge_empty_room!, "anything")
      """)

      assert Script.get_variable_value(script, "to_pick") == []
    end

    test "case-insensitive search matches items" do
      {:ok, room} = Record.create_entity(key: "gc_edge_case_room")
      {:ok, _apple} = Record.create_entity(key: "gc_edge_case_apple", location: room)
      Record.set_attribute("gc_edge_case_apple", "name", "Red Apple")

      script = run("""
      to_pick = search.match(!gc_edge_case_room!, "red apple")
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert length(to_pick) == 1
    end

    test "partial name match finds items" do
      {:ok, room} = Record.create_entity(key: "gc_edge_partial_room")
      {:ok, _apple} = Record.create_entity(key: "gc_edge_partial_apple", location: room)
      Record.set_attribute("gc_edge_partial_apple", "name", "red apple")

      script = run("""
      to_pick = search.match(!gc_edge_partial_room!, "red")
      """)

      to_pick = Script.get_variable_value(script, "to_pick")
      assert length(to_pick) == 1
    end

    test "moving then displaying preserves picked quantities" do
      {:ok, room} = Record.create_entity(key: "gc_edge_preserve_room")
      {:ok, _character} = Record.create_entity(key: "gc_edge_preserve_char")
      {:ok, _coin} = Record.create_entity(key: "gc_edge_preserve_coin")
      Record.set_attribute("gc_edge_preserve_coin", "stackable", true)
      Record.set_attribute("gc_edge_preserve_coin", "name", "gold coin")
      Record.set_method("gc_edge_preserve_coin", "__namefor__",
        [{"viewer", [index: 0, type: :entity]}, {"quantity", [index: 1, type: :int, default: 1]}],
        """
        if quantity == 1:
            return "a gold coin"
        endif
        return f"{quantity} gold coins"
        """)
      Record.add_stackable(room, Record.get_entity("gc_edge_preserve_coin"), 100)

      script = run("""
      character = !gc_edge_preserve_char!
      to_pick = search.match(!gc_edge_preserve_room!, "gold", limit=25)
      for item in to_pick:
          item.location = character
      done
      display = names.group(to_pick, viewer=character)
      """)

      display = Script.get_variable_value(script, "display")
      assert display == ["25 gold coins"]
    end

    test "index selection with get: pick second matching stack" do
      {:ok, room} = Record.create_entity(key: "gc_edge_idx_room")
      {:ok, character} = Record.create_entity(key: "gc_edge_idx_char")

      {:ok, _ra} = Record.create_entity(key: "gc_edge_idx_ra")
      Record.set_attribute("gc_edge_idx_ra", "stackable", true)
      Record.set_attribute("gc_edge_idx_ra", "name", "red apple")
      Record.add_stackable(room, Record.get_entity("gc_edge_idx_ra"), 5)

      {:ok, _ga} = Record.create_entity(key: "gc_edge_idx_ga")
      Record.set_attribute("gc_edge_idx_ga", "stackable", true)
      Record.set_attribute("gc_edge_idx_ga", "name", "green apple")
      Record.add_stackable(room, Record.get_entity("gc_edge_idx_ga"), 3)

      run("""
      to_pick = search.match(!gc_edge_idx_room!, "apple", index=2, limit=2)
      for item in to_pick:
          item.location = !gc_edge_idx_char!
      done
      """)

      ra = Record.get_entity("gc_edge_idx_ra")
      ga = Record.get_entity("gc_edge_idx_ga")

      assert Record.get_stackable_quantity(character, ra) == 0
      assert Record.get_stackable_quantity(character, ga) == 2
      assert Record.get_stackable_quantity(room, ga) == 1
    end
  end
end
