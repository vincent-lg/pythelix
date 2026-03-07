defmodule Pythelix.Scripting.Format.StringTest do
  use ExUnit.Case, async: true

  alias Pythelix.Scripting.Format.String, as: FString

  describe "split_expression/1" do
    test "simple variable" do
      assert FString.split_expression("x") == {"x", nil, nil}
    end

    test "variable with conversion" do
      assert FString.split_expression("x!r") == {"x", "r", nil}
      assert FString.split_expression("x!s") == {"x", "s", nil}
      assert FString.split_expression("x!c") == {"x", "c", nil}
    end

    test "variable with spec" do
      assert FString.split_expression("x:05d") == {"x", nil, "05d"}
    end

    test "variable with conversion and spec" do
      assert FString.split_expression("x!r:>10") == {"x", "r", ">10"}
      assert FString.split_expression("name!c:>20") == {"name", "c", ">20"}
    end

    test "expression with parens preserves colon inside" do
      assert FString.split_expression("func(a, b)") == {"func(a, b)", nil, nil}
      assert FString.split_expression("func(a, b):05") == {"func(a, b)", nil, "05"}
    end

    test "expression with brackets preserves colon inside" do
      assert FString.split_expression("d[\"a:b\"]") == {"d[\"a:b\"]", nil, nil}
      assert FString.split_expression("d[\"a:b\"]:>10") == {"d[\"a:b\"]", nil, ">10"}
    end

    test "entity syntax" do
      assert FString.split_expression("!animal!") == {"!animal!", nil, nil}
    end

    test "entity syntax with conversion" do
      assert FString.split_expression("!animal!!c") == {"!animal!", "c", nil}
    end

    test "entity syntax with spec" do
      assert FString.split_expression("!animal!:>10") == {"!animal!", nil, ">10"}
    end

    test "entity syntax with conversion and spec" do
      assert FString.split_expression("!animal!!c:>10") == {"!animal!", "c", ">10"}
    end

    test "no false conversion on non-conversion char" do
      assert FString.split_expression("x!d") == {"x!d", nil, nil}
    end

    test "string literal with colon inside" do
      # The colon inside quotes should not be treated as spec separator
      assert FString.split_expression("\"a:b\"") == {"\"a:b\"", nil, nil}
    end
  end
end
