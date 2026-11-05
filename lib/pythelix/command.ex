defmodule Pythelix.Command do
  @moduledoc """
  Module to manipulate commands in Pythelix.
  """

  alias Pythelix.Command.Syntax
  alias Pythelix.Generic
  alias Pythelix.Record

  def add_base_command_entity(entities) do
    [
      %{
        virtual: true,
        key: Generic.command(),
        attributes: %{},
        methods: %{}
      }
      | entities
    ]
  end

  @doc """
  Returns a list of command keys (children of the generic command).
  """
  def get_command_names(key) do
    key
    |> Record.get_entity()
    |> then(fn
      nil ->
        []

      command ->
        command
        |> Record.get_attribute("name", "")
        |> names_of(command)
    end)
  end

  # `name = None` turns a command off, whatever aliases it would otherwise answer
  # to: the entity still exists, and it just isn't exposed.
  defp names_of(name, _command) when name in [nil, :none], do: []

  defp names_of(name, command) do
    [name]
    |> Enum.concat(Record.get_attribute(command, "aliases", []))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def build_syntax_pattern(key) do
    key
    |> Record.get_entity()
    |> then(fn
      nil ->
        :error

      command ->
        syntax = Record.get_attribute(command, "syntax", "")
        build_pattern_for(command, syntax)
    end)
  end

  defp build_pattern_for(command, "") do
    Record.set_attribute(command.key, "syntax_pattern", [])
  end

  defp build_pattern_for(command, syntax) do
    case Syntax.Parser.syntax(syntax) do
      {:ok, pattern, "", _, _, _} ->
        pattern = Syntax.Parser.classify(syntax, pattern)
        Record.set_attribute(command.key, "syntax_pattern", pattern)

      error ->
        error
    end
  end
end
