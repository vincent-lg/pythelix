defmodule Pythelix.Scenario.Runner do
  @moduledoc """
  Play a [scenario](`Pythelix.Scenario`) against the running game.

  Nothing here is a test double. A player in a scenario is a real client
  entity whose `pid` points at a `Pythelix.Scenario.Collector` instead of at a
  socket — which is all a socket ever was, as far as the engine is concerned.
  Input goes through `Pythelix.Network.TCP.Client.process_input/3`, the same
  entry point the telnet server uses, so menus, command parsing, matching,
  broadcasts and prompts all behave exactly as they do for a real player. A
  scenario that passes is therefore evidence about the game, not about a
  simulation of it.

  The caller is expected to have the application started and to clean up after
  itself. `Pythelix.Task.Scenario` does both for the command line; tests drive
  this module directly.
  """

  alias Pythelix.{Entity, Record}
  alias Pythelix.Scenario
  alias Pythelix.Scenario.{Collector, Failure, Step}
  alias Pythelix.Scripting

  # How long to wait for a player's first message after an input, in ms. Only
  # paid in full when an expectation is about to fail anyway.
  @settle 300

  defstruct players: %{}, next_id: 1, failures: [], steps: 0

  @doc """
  Play a scenario and report what didn't hold.

  Returns `{:ok, count}` with the number of steps played, or `{:failed,
  failures}`. Playing continues past a failed expectation: one wrong message
  rarely invalidates the rest of the transcript, and seeing every failure at
  once is worth more than seeing only the first.
  """
  @spec run(Scenario.t()) :: {:ok, non_neg_integer()} | {:failed, [Failure.t()]}
  def run(%Scenario{} = scenario) do
    state = Enum.reduce(scenario.steps, %__MODULE__{}, &play/2)

    Enum.each(state.players, fn {_name, player} -> Collector.stop(player.collector) end)

    case Enum.reverse(state.failures) do
      [] -> {:ok, state.steps}
      failures -> {:failed, failures}
    end
  end

  # Steps

  defp play(%Step{kind: :apply, text: path} = step, state) do
    case Pythelix.World.apply(fixture_path(path)) do
      {:ok, _path, _number, _notices} ->
        count(state)

      :nofile ->
        fail(state, step, "there is no worldlet at #{inspect(path)}")

      {:error, reason} ->
        fail(state, step, "the worldlet could not be applied:\n#{indent(reason)}")
    end
  end

  defp play(%Step{kind: :given, actor: name, text: room} = step, state) do
    cond do
      Map.has_key?(state.players, name) ->
        fail(state, step, "#{name} has already joined")

      Record.get_entity(strip_key(room)) == nil ->
        fail(state, step, "there is no entity with the key #{room}")

      true ->
        state |> connect(name, room) |> count()
    end
  end

  defp play(%Step{kind: :connect, actor: name} = step, state) do
    if Map.has_key?(state.players, name) do
      fail(state, step, "#{name} has already joined")
    else
      state |> open_client(name) |> count()
    end
  end

  defp play(%Step{kind: :place} = step, state) do
    prototype = Record.get_entity(strip_key(step.text))
    {target, described} = destination(state, step.target)

    cond do
      prototype == nil ->
        fail(state, step, "there is no entity with the key #{step.text}")

      target == nil ->
        fail(state, step, "there is nowhere called #{described}")

      true ->
        place(prototype, step.count || 1, target)

        count(state)
    end
  end

  defp play(%Step{kind: :input, actor: name} = step, state) do
    with_player(state, step, name, fn _player ->
      # A new exchange begins: everything before it belongs to the previous
      # one, for every player, since typing here can reach the others.
      Enum.each(state.players, fn {_n, p} -> Collector.clear(p.collector) end)

      player = state.players[name]
      Pythelix.Network.TCP.Client.process_input(player.client_id, step.text, now())

      count(state)
    end)
  end

  defp play(%Step{kind: :sees, actor: name} = step, state) do
    with_player(state, step, name, fn player ->
      received = Collector.peek(player.collector, @settle)

      if Enum.any?(received, &String.contains?(&1, step.text)) do
        count(state)
      else
        fail(state, step, "#{name} did not see it", received)
      end
    end)
  end

  defp play(%Step{kind: :not_sees, actor: name} = step, state) do
    with_player(state, step, name, fn player ->
      received = Collector.peek(player.collector, @settle)

      if Enum.any?(received, &String.contains?(&1, step.text)) do
        fail(state, step, "#{name} saw it, and should not have", received)
      else
        count(state)
      end
    end)
  end

  defp with_player(state, step, name, fun) do
    case Map.fetch(state.players, name) do
      {:ok, player} -> fun.(player)
      :error -> fail(state, step, "#{name} has not joined; add: given #{name} in !some/room!")
    end
  end

  # Players

  # A client at the front door: connected, sitting in whatever menu the game
  # greets people with, and nobody yet. This is how a scenario tests the menus
  # themselves — logging in, making an account, choosing a name.
  defp open_client(state, name) do
    client_id = state.next_id
    collector = Collector.start()
    Pythelix.Network.TCP.Client.initialize_client(client_id, collector)

    player = %{name: name, client_id: client_id, collector: collector}

    %{state | players: Map.put(state.players, name, player), next_id: client_id + 1}
  end

  # Open a client, then build a player the way `menu/new/player` does and hand
  # over to `menu/near_game` — the menu that puts a character into the world —
  # rather than repeating what it does here. A game that changes how players
  # enter changes how scenarios enter, for free.
  defp connect(state, name, room) do
    state = open_client(state, name)
    client_id = state.players[name].client_id

    {:ok, _} =
      Scripting.eval("""
      client = !client/#{client_id}!
      player = Entity(parent=!generic/player!)
      player.name = #{inspect(name)}
      account = Entity(parent=!generic/account!)
      account.username = #{inspect(name)}
      account.players.append(player)
      player.account = account
      player.former_location = #{room}
      client.player = player
      client.location = !menu/near_game!
      """)

    state
  end

  # Things

  # Where a `given ... in ...` puts something: an entity by key, or a player
  # by name, meaning their character's inventory.
  defp destination(_state, "!" <> _ = key), do: {Record.get_entity(strip_key(key)), key}

  defp destination(state, name) do
    case Map.fetch(state.players, name) do
      {:ok, player} -> {owner_of(player), name}
      :error -> {nil, name}
    end
  end

  defp owner_of(player) do
    case Record.get_entity("client/#{player.client_id}") do
      nil -> nil
      client -> Record.get_attribute(client, "owner")
    end
  end

  # A stackable becomes one stack of N; anything else becomes N copies of the
  # prototype. Which one it is, is the prototype's business, not the
  # scenario's — a scenario says "30 gold coins", not how they are stored.
  defp place(prototype, count, target) do
    key = Entity.get_id_or_key(prototype)
    into = Entity.get_id_or_key(target)

    if Record.get_attribute(prototype, "stackable") == true do
      {:ok, _} =
        Scripting.eval("""
        stack = stackable(#{reference(key)}, #{count})
        stack.location = #{reference(into)}
        """)
    else
      Enum.each(1..count//1, fn _ ->
        {:ok, _} =
          Scripting.eval("Entity(parent=#{reference(key)}, location=#{reference(into)})")
      end)
    end
  end

  defp reference(id_or_key) when is_integer(id_or_key), do: "entity(#{id_or_key})"
  defp reference(key), do: "!#{key}!"

  # Helpers

  defp count(state), do: %{state | steps: state.steps + 1}

  defp fail(state, step, message, received \\ []) do
    failure = %Failure{
      line: step.line,
      source: Step.render(step),
      message: message,
      expected: step.text,
      received: received
    }

    %{state | failures: [failure | state.failures], steps: state.steps + 1}
  end

  defp strip_key(text), do: String.trim(text, "!")

  # `apply` names a fixture relative to the fixtures directory, so a scenario
  # says `apply combat/goblins.txt` rather than repeating where fixtures live.
  # A path that resolves as given still works, for a worldlet kept elsewhere.
  defp fixture_path(path) do
    fixture = Path.join(fixtures_directory(), path)

    # The fixtures directory first, then the game's root — never the directory
    # the command happened to be launched from, which is `bin` as often as not.
    (File.exists?(fixture) && fixture) || Pythelix.Paths.resolve(path)
  end

  defp fixtures_directory do
    Application.get_env(:pythelix, :scenarios_path, Path.join(File.cwd!(), "scenarios"))
    |> Path.join("fixtures")
  end

  defp indent(text) do
    text
    |> to_string()
    |> String.split("\n")
    |> Enum.map_join("\n", &("    " <> &1))
  end

  defp now, do: System.monotonic_time(:microsecond)
end
