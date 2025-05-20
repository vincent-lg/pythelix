defmodule Pythelix.Command do
  @moduledoc """
  Module to manipulate commands in Pythelix.
  """

  @generic_command "generic/command"

  alias Pythelix.Command.Syntax
  alias Pythelix.Record

  def add_base_command_entity(entities) do
    [
      %{
        virtual: true,
        key: @generic_command,
        attributes: %{},
        methods: %{},
      } | entities
    ]
  end

  @doc """
  Returns a list of command keys (children of the generic command).
  """
  def get_command_keys() do
    @generic_command
    |> Record.get_children_id_or_key()
  end

  def get_command_names(key) do
    key
    |> Record.get_entity()
    |> then(fn
      nil ->
        []

      command ->
        [Record.get_attribute(command, "name", "")]
        |> Enum.concat(Record.get_attribute(command, "aliases", []))
        |> Enum.reject(fn name -> name == nil end)
        |> Enum.uniq()
    end)
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
        Record.set_attribute(command.key, "syntax_pattern", pattern)

      error ->
        error
    end
  end
end
