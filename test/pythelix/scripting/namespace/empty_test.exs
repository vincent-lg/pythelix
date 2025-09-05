defmodule Pythelix.Scripting.Namespace.EmptyTest do
  @moduledoc """
  Module to test scripting namespaces with no method.
  """

  use Pythelix.ScriptingCase

  @expected ["True", "False", "1.0", "2", "None"]

  describe "__repr__" do
    test "iterate over empty namespaces to repr them" do
      expected = @expected ++ ["\"ok\""]
      for str_value <- expected do
        result = expr_ok("v = #{str_value}\nv.__repr__()")
        assert result == str_value
      end
    end

    test "iterate over empty namespaces to str them" do
      expected =
        @expected
        |> Enum.map(& {&1, &1})
        |> then(& &1 ++ [{"\"ok\"", "ok"}])

      for {expression, str_value} <- expected do
        result = expr_ok("v = #{expression}\nv.__str__()")
        assert result == str_value
      end
    end

    test "iterate over empty namespaces to builtin-repr them" do
      expected = @expected ++ ["\"ok\""]
      for str_value <- expected do
        result = expr_ok("v = #{str_value}\nrepr(v)")
        assert result == str_value
      end
    end

    test "iterate over empty namespaces to builtin-str them" do
      expected =
        @expected
        |> Enum.map(& {&1, &1})
        |> then(& &1 ++ [{"\"ok\"", "ok"}])

      for {expression, str_value} <- expected do
        result = expr_ok("v = #{expression}\nstr(v)")
        assert result == str_value
      end
    end
  end
end
