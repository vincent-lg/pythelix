defmodule Pythelix.Scripting.Namespace.Tuple do
  @moduledoc """
  Module defining the tuple object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Object.Tuple

  defmet __add__(script, namespace), [
    {:other, index: 0, type: :any}
  ] do
    %Tuple{elements: elems1} = Store.get_value(namespace.self, recursive: false)
    %Tuple{elements: elems2} = Store.get_value(namespace.other, recursive: false)
    {script, %Tuple{elements: elems1 ++ elems2}}
  end

  defmet __mul__(script, namespace), [
    {:times, index: 0, type: :int}
  ] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    result = List.duplicate(elements, namespace.times) |> List.flatten()
    {script, %Tuple{elements: result}}
  end

  defmet __bool__(script, namespace), [] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    {script, elements != []}
  end

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    {script, Enum.member?(elements, namespace.element)}
  end

  defmet __getitem__(script, namespace), [
    {:item, index: 0, type: :int}
  ] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)

    case Enum.at(elements, namespace.item, :out) do
      :out ->
        message = "tuple index out of range"
        {Script.raise(script, IndexError, message), :none}

      value ->
        {script, value}
    end
  end

  defmet __iter__(script, namespace), [] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    {script, elements}
  end

  defmet __setitem__(script, _namespace), [
    {:item, index: 0, type: :any},
    {:value, index: 1, type: :any}
  ] do
    {Script.raise(script, TypeError, "'tuple' object does not support item assignment"), :none}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet count(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    count = Enum.count(elements, fn item -> item == namespace.value end)
    {script, count}
  end

  defmet index(script, namespace), [
    {:value, index: 0, type: :any},
    {:start, index: 1, type: :int, default: 0},
    {:stop, index: 2, type: :int, default: :end}
  ] do
    %Tuple{elements: elements} = Store.get_value(namespace.self, recursive: false)
    tuple_size = length(elements)

    start_index =
      if namespace.start < 0, do: max(0, tuple_size + namespace.start), else: namespace.start

    stop_index =
      case namespace.stop do
        :end -> tuple_size
        val when val < 0 -> max(0, tuple_size + val)
        val -> min(val, tuple_size)
      end

    if start_index >= stop_index do
      {Script.raise(
         script,
         ValueError,
         "#{Display.repr(script, namespace.value)} is not in tuple"
       ), :none}
    else
      search_list = Enum.slice(elements, start_index, stop_index - start_index)

      case Enum.find_index(search_list, fn item -> item == namespace.value end) do
        nil ->
          {Script.raise(
             script,
             ValueError,
             "#{Display.repr(script, namespace.value)} is not in tuple"
           ), :none}

        found_index ->
          {script, start_index + found_index}
      end
    end
  end

  defp repr(script, self) do
    %Tuple{elements: elements} = Store.get_value(self)

    inner =
      elements
      |> Enum.map(fn value -> Display.repr(script, value) end)
      |> Enum.join(", ")

    result =
      case length(elements) do
        1 -> "(#{inner},)"
        _ -> "(#{inner})"
      end

    {script, result}
  end
end
