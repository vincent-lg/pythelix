defmodule Pythelix.Scripting.Namespace.List do
  @moduledoc """
  Module defining the list object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    {script, Enum.member?(list, namespace.element)}
  end

  defmet __getitem__(script, namespace), [
    {:item, index: 0, type: :int}
  ] do
    list = Store.get_value(namespace.self, recursive: false)

    case Enum.at(list, namespace.item, :out) do
      :out ->
        message = "list index out of range"
        {Script.raise(script, IndexError, message), :none}

      value ->
        {script, value}
    end
  end

  defmet __setitem__(script, namespace), [
    {:item, index: 0, type: :int},
    {:value, index: 1, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)

    case Enum.at(list, namespace.item, :out) do
      :out ->
        message = "list index out of range"
        {Script.raise(script, IndexError, message), :none}

      _ ->
        list = List.replace_at(list, namespace.item, namespace.value)
        Store.update_reference(namespace.self, list)
        {script, :none}
      end
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet append(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    former = Store.get_value(namespace.self, recursive: false)
    Store.update_reference(namespace.self, List.insert_at(former, -1, namespace.value))

    {script, :none}
  end

  defmet clear(script, namespace), [] do
    Store.update_reference(namespace.self, [])
    {script, :none}
  end

  defmet copy(script, namespace), [] do
    list = Store.get_value(namespace.self, recursive: false)
    {script, list}
  end

  defmet count(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    count = Enum.count(list, fn item -> item == namespace.value end)
    {script, count}
  end

  defmet extend(script, namespace), [
    {:iterable, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    iterable = Store.get_value(namespace.iterable, recursive: false)

    case iterable do
      items when is_list(items) ->
        Store.update_reference(namespace.self, list ++ items)
        {script, :none}

      _ ->
        {Script.raise(script, TypeError, "extend() argument must be iterable"), :none}
    end
  end

  defmet index(script, namespace), [
    {:value, index: 0, type: :any},
    {:start, index: 1, type: :int, default: 0},
    {:stop, index: 2, type: :int, default: :end}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    list_size = length(list)

    start_index = if namespace.start < 0, do: max(0, list_size + namespace.start), else: namespace.start
    stop_index = case namespace.stop do
      :end -> list_size
      val when val < 0 -> max(0, list_size + val)
      val -> min(val, list_size)
    end

    if start_index >= stop_index do
      {Script.raise(script, ValueError, "#{Display.repr(script, namespace.value)} is not in list"), :none}
    else
      search_list = Enum.slice(list, start_index, stop_index - start_index)
      case Enum.find_index(search_list, fn item -> item == namespace.value end) do
        nil ->
          {Script.raise(script, ValueError, "#{Display.repr(script, namespace.value)} is not in list"), :none}
        found_index ->
          {script, start_index + found_index}
      end
    end
  end

  defmet insert(script, namespace), [
    {:index, index: 0, type: :int},
    {:value, index: 1, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    list_size = length(list)

    insert_index = cond do
      namespace.index < 0 -> max(0, list_size + namespace.index)
      namespace.index > list_size -> list_size
      true -> namespace.index
    end

    Store.update_reference(namespace.self, List.insert_at(list, insert_index, namespace.value))
    {script, :none}
  end

  defmet pop(script, namespace), [
    {:index, index: 0, type: :int, default: -1}
  ] do
    list = Store.get_value(namespace.self, recursive: false)
    list_size = length(list)

    if list_size == 0 do
      {Script.raise(script, IndexError, "pop from empty list"), :none}
    else
      pop_index = if namespace.index < 0 do
        list_size + namespace.index
      else
        namespace.index
      end

      if pop_index < 0 or pop_index >= list_size do
        {Script.raise(script, IndexError, "pop index out of range"), :none}
      else
        {value, updated_list} = List.pop_at(list, pop_index)
        Store.update_reference(namespace.self, updated_list)
        {script, value}
      end
    end
  end

  defmet remove(script, namespace), [
    {:value, index: 0, type: :any}
  ] do
    list = Store.get_value(namespace.self, recursive: false)

    case Enum.find_index(list, fn item -> item == namespace.value end) do
      nil ->
        {Script.raise(script, ValueError, "list.remove(x): x not in list"), :none}
      found_index ->
        {_removed, updated_list} = List.pop_at(list, found_index)
        Store.update_reference(namespace.self, updated_list)
        {script, :none}
    end
  end

  defmet reverse(script, namespace), [] do
    list = Store.get_value(namespace.self, recursive: false)
    Store.update_reference(namespace.self, Enum.reverse(list))
    {script, :none}
  end

  defmet sort(script, namespace), [
    {:reverse, index: 0, type: :bool, default: false}
  ] do
    list = Store.get_value(namespace.self, recursive: false)

    try do
      sorted_list = if namespace.reverse do
        Enum.sort(list, :desc)
      else
        Enum.sort(list)
      end

      Store.update_reference(namespace.self, sorted_list)
      {script, :none}
    rescue
      _ ->
        {Script.raise(script, TypeError, "'<' not supported between instances of different types"), :none}
    end
  end

  defp repr(script, self) do
    Store.get_value(self)
    |> Enum.map(fn
      :ellipsis -> "[...]"
      value -> Display.repr(script, value)
    end)
    |> Enum.join(", ")
    |> then(fn list -> {script, "[#{list}]"} end)
  end
end
