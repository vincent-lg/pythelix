defmodule Pythelix.Scripting.Format.SpecTest do
  use ExUnit.Case, async: true

  alias Pythelix.Scripting.Format.Spec

  describe "parse/1" do
    test "nil and empty return nil" do
      assert {:ok, nil} = Spec.parse(nil)
      assert {:ok, nil} = Spec.parse("")
    end

    test "width only" do
      assert {:ok, %Spec{width: 10}} = Spec.parse("10")
    end

    test "zero-pad with width" do
      assert {:ok, %Spec{zero_pad: true, width: 5}} = Spec.parse("05")
    end

    test "align with width" do
      assert {:ok, %Spec{align: ">", width: 10}} = Spec.parse(">10")
      assert {:ok, %Spec{align: "<", width: 10}} = Spec.parse("<10")
      assert {:ok, %Spec{align: "^", width: 10}} = Spec.parse("^10")
    end

    test "fill and align with width" do
      assert {:ok, %Spec{fill: "_", align: ">", width: 10}} = Spec.parse("_>10")
      assert {:ok, %Spec{fill: "0", align: ">", width: 5}} = Spec.parse("0>5")
      assert {:ok, %Spec{fill: ".", align: "^", width: 20}} = Spec.parse(".^20")
    end

    test "precision" do
      assert {:ok, %Spec{precision: 2}} = Spec.parse(".2")
      assert {:ok, %Spec{precision: 2, type: "f"}} = Spec.parse(".2f")
    end

    test "type only" do
      assert {:ok, %Spec{type: "d"}} = Spec.parse("d")
      assert {:ok, %Spec{type: "f"}} = Spec.parse("f")
      assert {:ok, %Spec{type: "s"}} = Spec.parse("s")
    end

    test "full spec" do
      assert {:ok, %Spec{fill: "0", align: ">", width: 8, precision: 2, type: "f"}} =
               Spec.parse("0>8.2f")
    end

    test "zero-pad with width and type" do
      assert {:ok, %Spec{zero_pad: true, width: 5, type: "d"}} = Spec.parse("05d")
    end

    test "invalid type" do
      assert {:error, {:invalid_format_spec, _}} = Spec.parse("z")
    end

    test "missing precision after dot" do
      assert {:error, {:invalid_format_spec, _}} = Spec.parse(".f")
    end
  end

  describe "apply/2" do
    test "integer with width and zero-pad" do
      {:ok, spec} = Spec.parse("05d")
      assert Spec.apply(5, spec) == "00005"
    end

    test "integer right-aligned" do
      {:ok, spec} = Spec.parse(">10d")
      assert Spec.apply(42, spec) == "        42"
    end

    test "integer left-aligned" do
      {:ok, spec} = Spec.parse("<10d")
      assert Spec.apply(42, spec) == "42        "
    end

    test "integer center-aligned" do
      {:ok, spec} = Spec.parse("^10d")
      assert Spec.apply(42, spec) == "    42    "
    end

    test "float with precision" do
      {:ok, spec} = Spec.parse(".2f")
      assert Spec.apply(3.14159, spec) == "3.14"
    end

    test "float with width and precision" do
      {:ok, spec} = Spec.parse("08.2f")
      assert Spec.apply(3.14159, spec) == "00003.14"
    end

    test "integer treated as float" do
      {:ok, spec} = Spec.parse(".2f")
      assert Spec.apply(5, spec) == "5.00"
    end

    test "string left-aligned by default" do
      {:ok, spec} = Spec.parse("10s")
      assert Spec.apply("hi", spec) == "hi        "
    end

    test "string right-aligned" do
      {:ok, spec} = Spec.parse(">10s")
      assert Spec.apply("hi", spec) == "        hi"
    end

    test "string center-aligned with fill" do
      {:ok, spec} = Spec.parse("*^10s")
      assert Spec.apply("hi", spec) == "****hi****"
    end

    test "no padding when value exceeds width" do
      {:ok, spec} = Spec.parse("3d")
      assert Spec.apply(12345, spec) == "12345"
    end

    test "width only defaults alignment by type" do
      {:ok, spec} = Spec.parse("10")
      # strings default left
      assert Spec.apply("hi", spec) == "hi        "
      # but with numeric type, default right
      {:ok, spec} = Spec.parse("10d")
      assert Spec.apply(5, spec) == "         5"
    end

    test "precision with no type on float" do
      {:ok, spec} = Spec.parse(".3")
      assert Spec.apply(2.71828, spec) == "2.718"
    end

    test "precision with no type on integer" do
      {:ok, spec} = Spec.parse(".2")
      assert Spec.apply(5, spec) == "5.00"
    end

    test "float to int via d type" do
      {:ok, spec} = Spec.parse("d")
      assert Spec.apply(3.7, spec) == "3"
    end
  end
end
