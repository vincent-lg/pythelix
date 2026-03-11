defmodule Pythelix.Scripting.Namespace.HorizontalListGroup do
  @moduledoc """
  Namespace for HorizontalListGroup display objects.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting.Object.HorizontalListGroup

  # Read-only attributes

  defattr entries(_script, self) do
    %HorizontalListGroup{entries: entries} = Store.get_value(self)
    entries
  end

  # Writable options (readable + writable with type checking)

  defopt(:title, :str)

  # Methods

  defmet add_entry(script, namespace), [
    {:text, index: 0, type: :str}
  ] do
    text = Store.get_value(namespace.text)
    group = Store.get_value(namespace.self)
    updated = %{group | entries: group.entries ++ [text]}
    Store.update_reference(namespace.self, updated)
    {script, namespace.self}
  end

  defmet __repr__(script, namespace), [] do
    group = Store.get_value(namespace.self)
    entry_count = length(group.entries)
    {script, "<HorizontalListGroup '#{group.title}' (#{entry_count} entries)>"}
  end

  defmet __str__(script, namespace), [] do
    group = Store.get_value(namespace.self)
    {script, group.title}
  end
end
