defmodule Pythelix.Generic do
  @moduledoc """
  Centralized access to configurable generic entity names.

  Generic entity keys can be overridden in config:

      config :pythelix, :generic_entities,
        client: "generic/client",
        character: "generic/character",
        menu: "generic/menu",
        command: "generic/command",
        rangen: "generic/rangen",
        calendar: "generic/calendar"
  """

  @defaults %{
    client: "generic/client",
    character: "generic/character",
    menu: "generic/menu",
    command: "generic/command",
    rangen: "generic/rangen",
    calendar: "generic/calendar"
  }

  def client, do: get(:client)
  def character, do: get(:character)
  def menu, do: get(:menu)
  def command, do: get(:command)
  def rangen, do: get(:rangen)
  def calendar, do: get(:calendar)

  defp get(key) do
    config = Application.get_env(:pythelix, :generic_entities, [])
    Keyword.get(config, key, @defaults[key])
  end
end
