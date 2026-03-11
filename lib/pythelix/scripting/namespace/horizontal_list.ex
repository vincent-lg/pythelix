defmodule Pythelix.Scripting.Namespace.HorizontalList do
  @moduledoc """
  Namespace for HorizontalList display objects.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.{HorizontalList, HorizontalListGroup}
  alias Pythelix.Scripting.Object.Reference

  # Read-only attributes

  defattr groups(_script, self) do
    %HorizontalList{groups: groups} = Store.get_value(self, recursive: false)
    groups
  end

  # Writable options (readable + writable with type checking)

  defopt(:indent, :int)
  defopt(:columns, :int)
  defopt(:col_width, :int)

  # Methods

  defmet add_group(script, namespace), [
    {:title, index: 0, type: :str, default: ""}
  ] do
    title = Store.get_value(namespace.title)
    list = Store.get_value(namespace.self, recursive: false)
    group = %HorizontalListGroup{title: title}
    group_ref = Store.new_reference(group, script.id, namespace.self)
    updated = %{list | groups: list.groups ++ [group_ref]}
    Store.update_reference(namespace.self, updated)
    {script, group_ref}
  end

  defmet format(script, namespace), [] do
    list = resolve_groups(namespace.self)
    {script, do_format(list)}
  end

  defmet __repr__(script, namespace), [] do
    list = Store.get_value(namespace.self, recursive: false)
    group_count = length(list.groups)
    {script, "<HorizontalList (#{group_count} groups)>"}
  end

  defmet __str__(script, namespace), [] do
    list = resolve_groups(namespace.self)
    {script, do_format(list)}
  end

  # Helpers

  defp resolve_groups(self) do
    list = Store.get_value(self, recursive: false)

    resolved_groups =
      Enum.map(list.groups, fn
        %Reference{} = ref -> Store.get_value(ref)
        group -> group
      end)

    %{list | groups: resolved_groups}
  end

  # Formatting logic

  defp do_format(%HorizontalList{} = list) do
    indent = String.duplicate(" ", list.indent)

    list.groups
    |> Enum.map(&format_group(&1, indent, list.columns, list.col_width))
    |> Enum.join("\n")
  end

  defp format_group(%HorizontalListGroup{} = group, indent, columns, col_width) do
    lines =
      group.entries
      |> Enum.chunk_every(columns)
      |> Enum.map(fn row ->
        row
        |> Enum.map(&String.pad_trailing(&1, col_width))
        |> Enum.join()
        |> then(&(indent <> &1))
        |> String.trim_trailing()
      end)

    case group.title do
      "" -> Enum.join(lines, "\n")
      title -> Enum.join([title | lines], "\n")
    end
  end
end
