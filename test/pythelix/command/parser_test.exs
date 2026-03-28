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

  describe "parse/2 with a simple string arg pattern" do
    setup do
      %{pattern: [arg: [{:string, "message"}]]}
    end

    test "parses a single-character argument", %{pattern: pattern} do
      assert Parser.parse(pattern, "a") == {:ok, %{"message" => "a"}}
    end

    test "parses a multi-character argument", %{pattern: pattern} do
      assert Parser.parse(pattern, "hello world") == {:ok, %{"message" => "hello world"}}
    end

    test "reports missing argument for empty input", %{pattern: pattern} do
      assert Parser.parse(pattern, "") == {:mandatory, "message"}
    end
  end

  describe "parse/2 with delimiter pattern" do
    setup do
      # Pattern for: <object>, <container>
      %{pattern: [arg: [{:string, "object"}], delimiter: [","], arg: [{:string, "container"}]]}
    end

    test "parses with delimiter and spaces", %{pattern: pattern} do
      assert Parser.parse(pattern, "red apple, fig tree") ==
               {:ok, %{"object" => "red apple", "container" => "fig tree"}}
    end

    test "parses with delimiter and no spaces", %{pattern: pattern} do
      assert Parser.parse(pattern, "red apple,fig tree") ==
               {:ok, %{"object" => "red apple", "container" => "fig tree"}}
    end

    test "parses with delimiter and extra spaces", %{pattern: pattern} do
      assert Parser.parse(pattern, "red apple , fig tree") ==
               {:ok, %{"object" => "red apple", "container" => "fig tree"}}
    end

    test "parses single-char args around delimiter", %{pattern: pattern} do
      assert Parser.parse(pattern, "a,b") == {:ok, %{"object" => "a", "container" => "b"}}
    end

    test "parses single-char args with spaces around delimiter", %{pattern: pattern} do
      assert Parser.parse(pattern, "a, b") == {:ok, %{"object" => "a", "container" => "b"}}
    end
  end

  describe "syntax classification" do
    alias Pythelix.Command.Syntax.Parser, as: SyntaxParser

    test "multi-char token surrounded by spaces is a keyword" do
      {:ok, pattern, "", _, _, _} = SyntaxParser.syntax("<object> from <container>")
      pattern = SyntaxParser.classify("<object> from <container>", pattern)
      assert Enum.any?(pattern, &match?({:keyword, ["from"]}, &1))
    end

    test "single-char token surrounded by spaces is a keyword" do
      {:ok, pattern, "", _, _, _} = SyntaxParser.syntax("<object> f <container>")
      pattern = SyntaxParser.classify("<object> f <container>", pattern)
      assert Enum.any?(pattern, &match?({:keyword, ["f"]}, &1))
    end

    test "single-char token not surrounded by spaces is a delimiter" do
      {:ok, pattern, "", _, _, _} = SyntaxParser.syntax("<object>, <container>")
      pattern = SyntaxParser.classify("<object>, <container>", pattern)
      assert Enum.any?(pattern, &match?({:delimiter, [","]}, &1))
    end

    test "single-char token adjacent on both sides is a delimiter" do
      {:ok, pattern, "", _, _, _} = SyntaxParser.syntax("<object>f<container>")
      pattern = SyntaxParser.classify("<object>f<container>", pattern)
      assert Enum.any?(pattern, &match?({:delimiter, ["f"]}, &1))
    end

    test "multi-char token adjacent on both sides is still a keyword" do
      {:ok, pattern, "", _, _, _} = SyntaxParser.syntax("<object>fr<container>")
      pattern = SyntaxParser.classify("<object>fr<container>", pattern)
      assert Enum.any?(pattern, &match?({:keyword, ["fr"]}, &1))
    end
  end
end
