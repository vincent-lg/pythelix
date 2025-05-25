defmodule Pythelix.Scripting.REPLTest do
  use ExUnit.Case

  alias Pythelix.Scripting.REPL

  def assert_complete(input) do
    result = REPL.parse(input)
    assert :complete == result
  end

  def assert_need_more(input) do
    result = REPL.parse(input)
    assert match?({:need_more, _}, result)
  end

  def assert_error(input) do
    result = REPL.parse(input)
    assert match?({:error, _}, result)
  end

  describe "single line strings" do
    test "opening single tic" do
      input = ~s|'|
      assert_need_more(input)
    end

    test "opening single quote" do
      input = ~s|"|
      assert_need_more(input)
    end

    test "opening and closing single tic" do
      input = ~s|''|
      assert_complete(input)
    end

    test "opening and closing single quote" do
      input = ~s|""|
      assert_complete(input)
    end

    test "opening and closing single tic with content" do
      input = ~s|'ok'|
      assert_complete(input)
    end

    test "opening and closing single quote with content" do
      input = ~s|"ok"|
      assert_complete(input)
    end

    test "opening and closing single tic with newline" do
      input = ~s|'\n'|
      assert_error(input)
    end

    test "opening and closing single quote with newline" do
      input = ~s|"\n"|
      assert_error(input)
    end

    test "opening and closing single tic with escaped tics" do
      input = ~s|'o\\'k'|
      assert_complete(input)
    end

    test "opening and closing single quote with escaped quotes" do
      input = ~s|"o\\"k"|
      assert_complete(input)
    end
  end

  describe "multiple line strings" do
    test "opening triple tic" do
      input = ~s|'''|
      assert_need_more(input)
    end

    test "opening triple quote" do
      input = ~s|"""|
      assert_need_more(input)
    end

    test "opening and closing triple tic" do
      input = ~s|''''''|
      assert_complete(input)
    end

    test "opening and closing triple quote" do
      input = ~s|""""""|
      assert_complete(input)
    end

    test "opening and closing triple tic with content" do
      input = ~s|'''ok'''|
      assert_complete(input)
    end

    test "opening and closing triple quote with content" do
      input = ~s|"""ok"""|
      assert_complete(input)
    end

    test "opening and closing triple tic with newline" do
      input = ~s|'''\n'''|
      assert_complete(input)
    end

    test "opening and closing triple quote with newline" do
      input = ~s|"""\n"""|
      assert_complete(input)
    end
  end

  describe "parents" do
    test "opening parents without closing it" do
      input = ~s|(|
      assert_need_more(input)
    end

    test "opening parents with content but without closing it" do
      input = ~s|(1|
      assert_need_more(input)
    end

    test "opening and closing parents" do
      input = ~s|()|
      assert_complete(input)
    end

    test "opening and closing parents with content" do
      input = ~s|(1)|
      assert_complete(input)
    end

    test "opening and closing parents with incomplete string" do
      input = ~s|(')|
      assert_need_more(input)
    end

    test "opening and closing parents with complete string" do
      input = ~s|('')|
      assert_complete(input)
    end
  end

  describe "brackets" do
    test "opening bracket without closing it" do
      input = ~s|[|
      assert_need_more(input)
    end

    test "opening bracket with content but without closing it" do
      input = ~s|[1|
      assert_need_more(input)
    end

    test "opening and closing bracket" do
      input = ~s|[]|
      assert_complete(input)
    end

    test "opening and closing bracket with content" do
      input = ~s|[1]|
      assert_complete(input)
    end

    test "opening and closing bracket with incomplete string" do
      input = ~s|[']|
      assert_need_more(input)
    end

    test "opening and closing bracket with complete string" do
      input = ~s|['']|
      assert_complete(input)
    end
  end

  describe "if...endif" do
    test "if without endif" do
      input = ~s|if|
      assert_need_more(input)
    end

    test "if with content but without endif" do
      input = ~s|if 1|
      assert_need_more(input)
    end

    test "if with endif" do
      input = ~s|if endif|
      assert_complete(input)
    end

    test "if and endif with content" do
      input = ~s|if 1 endif|
      assert_complete(input)
    end

    test "if and endif with incomplete string" do
      input = ~s|if 'endif|
      assert_need_more(input)
    end

    test "if and endif with complete string" do
      input = ~s|if '' endif|
      assert_complete(input)
    end
  end

  describe "while...done" do
    test "while without done" do
      input = ~s|while|
      assert_need_more(input)
    end

    test "while with content but without done" do
      input = ~s|while 1|
      assert_need_more(input)
    end

    test "while with done" do
      input = ~s|while done|
      assert_complete(input)
    end

    test "while and done with content" do
      input = ~s|while 1 done|
      assert_complete(input)
    end

    test "while and done with incomplete string" do
      input = ~s|while 'done|
      assert_need_more(input)
    end

    test "while and done with complete string" do
      input = ~s|while '' done|
      assert_complete(input)
    end
  end

  describe "for...done" do
    test "for without done" do
      input = ~s|for|
      assert_need_more(input)
    end

    test "for with content but without done" do
      input = ~s|for 1|
      assert_need_more(input)
    end

    test "for with done" do
      input = ~s|for done|
      assert_complete(input)
    end

    test "for and done with content" do
      input = ~s|for 1 done|
      assert_complete(input)
    end

    test "for and done with incomplete string" do
      input = ~s|for 'done|
      assert_need_more(input)
    end

    test "for and done with complete string" do
      input = ~s|for '' done|
      assert_complete(input)
    end
  end
end
