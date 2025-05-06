defmodule Pythelix.Command.ParserTest do
  use ExUnit.Case

  alias Pythelix.Command.Parser

  describe "Pythelix.Command.Parser.parse/2" do
    setup do
      pattern = [
        keyword: ["get"],
        opt: [{:arg, [{:int, "number"}]}],
        arg: [{:string, "item"}],
        opt: [keyword: ["from"], arg: [{:string, "source"}]],
        opt: [keyword: ["into"], arg: [{:string, "destination"}]]
      ]

      %{pattern: pattern}
    end

    test "parses empty command", %{pattern: pattern} do
      input = ""

      obtained = Parser.parse(pattern, input)
      assert obtained == {:mandatory, "item"}
    end

    test "parses full command with number, source, destination", %{pattern: pattern} do
      input = "get 9 red apples from old tree into leather backpack"

      expected = %{
        "number" => 9,
        "item" => "red apples",
        "source" => "old tree",
        "destination" => "leather backpack"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end

    test "parses full command with no number, but source and destination", %{pattern: pattern} do
      input = "get red apples from old tree into leather backpack"

      expected = %{
        "item" => "red apples",
        "source" => "old tree",
        "destination" => "leather backpack"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end

    test "parses command with nmber and destination only", %{pattern: pattern} do
      input = "get 15 red apples into leather backpack"

      expected = %{
        "number" => 15,
        "item" => "red apples",
        "destination" => "leather backpack"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end

    test "parses command with nmber and source only", %{pattern: pattern} do
      input = "get 31 red apples from apple tree"

      expected = %{
        "number" => 31,
        "item" => "red apples",
        "source" => "apple tree"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end

    test "parses full command with number, reversed source and destination", %{pattern: pattern} do
      input = "get 9 red apples into leather backpack from old tree"

      expected = %{
        "number" => 9,
        "item" => "red apples",
        "source" => "old tree",
        "destination" => "leather backpack"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end

    test "parses full command with no number, but reversed source and destination", %{
      pattern: pattern
    } do
      input = "get red apples into leather backpack from old tree"

      expected = %{
        "item" => "red apples",
        "source" => "old tree",
        "destination" => "leather backpack"
      }

      obtained = Parser.parse(pattern, input)
      assert obtained == {:ok, expected}
    end
  end
end
