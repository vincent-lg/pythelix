defmodule Pythelix.Game.Modes.Handler do
  @moduledoc """
  Handle game mode input processing with configurable pipe operators.

  This module processes input that may contain pipe operators to switch between
  different game modes, where each mode represents a different character context.
  Pipe symbols are configurable through application config.
  """

  alias Pythelix.Game.Modes
  alias Pythelix.{Entity, Record}
  alias Pythelix.Menu.Handler, as: MenuHandler

  require Logger

  @doc """
  Handle user input within a game mode context.

  This function checks if the client's entity has game modes and processes
  pipe operators to switch between modes. If no game modes exist, it
  delegates to the regular menu handler.
  """
  @spec handle(Entity.t(), Entity.t(), String.t(), integer() | nil) :: :ok
  def handle(menu, client, input, start_time) do
    case get_owned_by_client(client) do
      nil ->
        # No entity, use regular menu processing
        MenuHandler.handle(menu, client, input, start_time)

      entity ->
        case get_game_modes(entity) do
          nil ->
            # No game modes, use regular menu processing
            MenuHandler.handle(menu, client, input, start_time, entity)

          game_modes ->
            process_game_mode_input(game_modes, client, input, start_time, entity)
        end
    end
  end

  @doc """
  Process input within game mode context, handling pipe operators.
  """
  def process_game_mode_input(game_modes, client, input, start_time, owner) do
    case parse_pipe_input(input) do
      {:pipe, net_movement, remaining_input} when net_movement != 0 ->
        direction = if net_movement > 0, do: :next, else: :previous
        count = abs(net_movement)
        handle_mode_switch(game_modes, client, direction, count, remaining_input, start_time, owner)

      {:no_pipe, clean_input} ->
        # No pipe operators, process with current active mode
        handle_with_active_mode(game_modes, client, clean_input, start_time, owner)
    end
  end

  @doc """
  Handle mode switching with pipe operators.
  """
  def handle_mode_switch(game_modes, client, direction, count, remaining_input, start_time, owner) do
    new_active_index = calculate_new_active_index(game_modes, direction, count)

    # Update the active mode
    updated_game_modes = %{game_modes | active: new_active_index}
    id_or_key = Entity.get_id_or_key(owner)
    Record.set_attribute(id_or_key, "game_modes", updated_game_modes)

    # Process remaining input with new active mode
    handle_with_active_mode(updated_game_modes, client, remaining_input, start_time, owner)
  end

  @doc """
  Handle input with the currently active game mode.
  """
  def handle_with_active_mode(game_modes, client, input, start_time, owner) do
    {menu, owner} = get_active_mode(game_modes, owner)

    MenuHandler.handle(menu, client, input, start_time, owner)
  end

  defp get_owned_by_client(client) do
    case Record.get_attribute(client, "owner") do
      nil -> nil
      entity -> entity
    end
  end

  defp get_game_modes(entity) do
    Record.get_attribute(entity, "game_modes")
  end

  defp get_active_mode(%Modes{} = modes, %Entity{} = owner) do
    Modes.get_active(modes, owner)
  end

  defp calculate_new_active_index(%Modes{active: current, game_modes: modes}, direction, count) do
    mode_count = length(modes)

    case direction do
      :next ->
        rem(current + count, mode_count)
      :previous ->
        rem(current - count + mode_count, mode_count)
    end
  end

  defp parse_pipe_input(input) do
    input = String.trim(input)
    config = get_pipe_config()

    case extract_and_analyze_pipes(input, config) do
      {0, remaining} ->
        {:no_pipe, remaining}

      {net_movement, remaining} ->
        {:pipe, net_movement, remaining}
    end
  end

  defp get_pipe_config do
    Application.get_env(:pythelix, Pythelix.Menu.Mode, symbols: [
      next: [">"],
      previous: ["<"]
    ])[:symbols]
  end

  defp extract_and_analyze_pipes(input, config) do
    next_symbols = Keyword.get(config, :next, [">"])
    previous_symbols = Keyword.get(config, :previous, ["<"])

    all_symbols = next_symbols ++ previous_symbols

    case find_pipe_sequence(input, all_symbols) do
      {pipe_sequence, remaining} ->
        net_movement = calculate_net_movement(pipe_sequence, next_symbols, previous_symbols)
        {net_movement, String.trim(remaining)}

      :no_pipes ->
        {0, input}
    end
  end

  defp find_pipe_sequence(input, symbols) do
    find_pipe_sequence(input, symbols, [])
  end

  defp find_pipe_sequence("", _symbols, acc) do
    if acc == [] do
      :no_pipes
    else
      {Enum.reverse(acc), ""}
    end
  end

  defp find_pipe_sequence(input, symbols, acc) do
    case find_matching_symbol_at_start(input, symbols) do
      {symbol, rest} ->
        find_pipe_sequence(rest, symbols, [symbol | acc])

      :no_match ->
        if acc == [] do
          :no_pipes
        else
          {Enum.reverse(acc), input}
        end
    end
  end

  defp find_matching_symbol_at_start(input, symbols) do
    Enum.find_value(symbols, fn symbol ->
      if String.starts_with?(input, symbol) do
        rest = String.slice(input, String.length(symbol)..-1//1)
        {symbol, rest}
      end
    end) || :no_match
  end

  defp calculate_net_movement(pipe_sequence, next_symbols, previous_symbols) do
    Enum.reduce(pipe_sequence, 0, fn symbol, acc ->
      cond do
        symbol in next_symbols -> acc + 1
        symbol in previous_symbols -> acc - 1
        true -> acc
      end
    end)
  end
end
