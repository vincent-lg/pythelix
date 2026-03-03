defmodule Pythelix.Scripting.Interpreter.MagicMethodsTest do
  @moduledoc """
  Tests for arithmetic magic methods (__add__, __mul__, etc.)
  on strings, lists, tuples, and numeric regression.
  """

  use Pythelix.ScriptingCase

  alias Pythelix.Scripting.Object.Tuple

  describe "string arithmetic" do
    test "string + string concatenation" do
      assert expr_ok(~s("o" + "k")) == "ok"
    end

    test "string * int repetition" do
      assert expr_ok(~s("n" * 3)) == "nnn"
    end

    test "int * string repetition (reversed operands)" do
      assert expr_ok(~s(3 * "n")) == "nnn"
    end

    test "string - string raises TypeError" do
      expr_fail(~s("a" - "b"))
    end
  end

  describe "list arithmetic" do
    test "list + list concatenation" do
      assert expr_ok("[1, 2, 3] + [4, 5, 6]") == [1, 2, 3, 4, 5, 6]
    end

    test "list * int repetition" do
      assert expr_ok("[1] * 2") == [1, 1]
    end

    test "int * list repetition (reversed operands)" do
      assert expr_ok("2 * [1]") == [1, 1]
    end

    test "empty list + empty list" do
      assert expr_ok("[] + []") == []
    end
  end

  describe "tuple arithmetic" do
    test "tuple + tuple concatenation" do
      assert expr_ok("(1, 2) + (3, 4)") == %Tuple{elements: [1, 2, 3, 4]}
    end

    test "tuple * int repetition" do
      assert expr_ok("(1,) * 3") == %Tuple{elements: [1, 1, 1]}
    end
  end

  describe "numeric regression" do
    test "integer addition" do
      assert expr_ok("5 + 3") == 8
    end

    test "float multiplication" do
      assert expr_ok("2.5 * 4") == 10.0
    end

    test "integer division" do
      assert expr_ok("10 / 2") == 5.0
    end
  end
end
