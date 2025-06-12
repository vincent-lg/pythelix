defmodule Pythelix.Menu do
  @moduledoc """
  Module to support Elixir menus.

  Menus are virtual entities in Elixir (they're not saved in the database).
  A client (TCP connection) is always inside a menu. They have several
  attributes and methods to change their behavior, and a list of commands.
  """

  alias Pythelix.Entity
  alias Pythelix.Method

  @doc """
  Return the prompt of the menu.

  If a method `get_prompt` on this menu exists, runs it. By default,
  it returns the menu's `prompt`, which is a string.

  Caution: executing a script can always lead to unexpected behavior.
  It is recommanded to execute this call inside a try/rescue block
  or in another process. `get_prompt` is often called by the command hub
  though, which means it can be fragile if not wrapped properly.
  """
  @spec get_prompt(Entity.t()) :: String.t()
  def get_prompt(menu) do
    Method.call_entity(menu, "get_prompt")
    |> then(& (is_binary(&1) && &1) || "error")
  end
end
