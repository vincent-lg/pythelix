defmodule Pythelix.Scripting.Namespace.Set do
  @moduledoc """
  Module defining the set object with its attributes and methods.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Display

  defmet __bool__(script, namespace), [] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, MapSet.size(set) > 0}
  end

  defmet __contains__(script, namespace), [
    {:element, index: 0, type: :any}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, MapSet.member?(set, namespace.element)}
  end

  defmet __repr__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __str__(script, namespace), [] do
    repr(script, namespace.self)
  end

  defmet __getitem__(script, _namespace), [
    {:item, index: 0, type: :any}
  ] do
    {Script.raise(script, TypeError, "'set' object is not subscriptable"), :none}
  end

  defmet __setitem__(script, _namespace), [
    {:item, index: 0, type: :any},
    {:value, index: 1, type: :any}
  ] do
    {Script.raise(script, TypeError, "'set' object does not support item assignment"), :none}
  end

  defmet add(script, namespace), [
    {:item, index: 0, type: :any}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    set = MapSet.put(set, namespace.item)

    Store.update_reference(namespace.self, set)

    {script, :none}
  end

  defmet clear(script, namespace), [] do
    set = MapSet.new()

    Store.update_reference(namespace.self, set)

    {script, :none}
  end

  defmet copy(script, namespace), [] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, set}
  end

  defmet difference(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.difference/2)

    if script.error do
      {script, :none}
    else
      {script, updated}
    end
  end

  defmet difference_update(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.difference/2)

    if script.error do
      {script, :none}
    else
      Store.update_reference(namespace.self, updated)

      {script, :none}
    end
  end

  defmet discard(script, namespace), [
    {:item, index: 0, type: :any}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    updated = MapSet.delete(set, namespace.item)

    Store.update_reference(namespace.self, updated)

    {script, :none}
  end

  defmet intersection(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.intersection/2)

    if script.error do
      {script, :none}
    else
      {script, updated}
    end
  end

  defmet intersection_update(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.intersection/2)

    if script.error do
      {script, :none}
    else
      Store.update_reference(namespace.self, updated)
      {script, :none}
    end
  end

  defmet isdisjoint(script, namespace), [
    {:other, index: 0, type: :set}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    other = Store.get_value(namespace.other, recursive: false)
    {script, MapSet.disjoint?(set, other)}
  end

  defmet issubset(script, namespace), [
    {:other, index: 0, type: :set}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    other = Store.get_value(namespace.other, recursive: false)
    {script, MapSet.subset?(set, other)}
  end

  defmet issuperset(script, namespace), [
    {:other, index: 0, type: :set}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    other = Store.get_value(namespace.other, recursive: false)
    {script, MapSet.subset?(other, set)}
  end

  defmet pop(script, namespace), [] do
    set = Store.get_value(namespace.self, recursive: false)

    case MapSet.to_list(set) do
      [_ | _] = list ->
        value = Enum.random(list)
        updated = MapSet.delete(set, value)
        Store.update_reference(namespace.self, updated)

        {script, value}
      [] ->
        {Script.raise(script, KeyError, "pop from an empty set"), :none}
    end
  end

  defmet remove(script, namespace), [
    {:item, index: 0, type: :any}
  ] do
    set = Store.get_value(namespace.self, recursive: false)

    if MapSet.member?(set, namespace.item) do
      updated = MapSet.delete(set, namespace.item)
      Store.update_reference(namespace.self, updated)

      {script, :none}
    else
      {Script.raise(script, KeyError, "#{inspect(namespace.item)} not found in set"), :none}
    end
  end

  defmet symmetric_difference(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    sym_diff = fn a, b -> MapSet.union(MapSet.difference(a, b), MapSet.difference(b, a)) end
    {script, updated} = reduce_set(script, namespace.args, set, sym_diff)

    if script.error do
      {script, :none}
    else
      {script, updated}
    end
  end

  defmet symmetric_difference_update(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    sym_diff = fn a, b -> MapSet.union(MapSet.difference(a, b), MapSet.difference(b, a)) end
    {script, updated} = reduce_set(script, namespace.args, set, sym_diff)

    if script.error do
      {script, :none}
    else
      Store.update_reference(namespace.self, updated)

      {script, :none}
    end
  end

  defmet union(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.union/2)

    if script.error do
      {script, :none}
    else
      {script, updated}
    end
  end

  defmet update(script, namespace), [
    {:args, index: 0, args: true}
  ] do
    set = Store.get_value(namespace.self, recursive: false)
    {script, updated} = reduce_set(script, namespace.args, set, &MapSet.union/2)

    if script.error do
      {script, :none}
    else
      Store.update_reference(namespace.self, updated)

      {script, :none}
    end
  end

  defp repr(script, self) do
    self = Store.get_value(self)
    MapSet.to_list(self)
    |> Enum.map(fn
      :ellipsis -> "{...}"
      value -> Display.repr(script, value)
    end)
    |> Enum.join(", ")
    |> then(fn set -> {script, "{#{set}}"} end)
  end

  defp reduce_set(script, args, set, reduce_fun) do
    Enum.reduce(args, {script, set}, fn arg, {script, set} ->
      case Store.get_value(arg, recursive: false) do
        %MapSet{} = other ->
          {script, reduce_fun.(set, other)}

        other ->
          message = "not a set: #{inspect(other)}"
          {Script.raise(script, TypeError, message), set}
      end
    end)
  end
end
