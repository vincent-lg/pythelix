defmodule Pythelix.Scripting.InputWaiter do
  @moduledoc """
  Manages scripts waiting for user input.

  Tracks waiting scripts by two keys:
  - `client_id` — for fast lookup on each input event (changes on reconnect).
  - `entity_id_or_key` — for reconnection: find the task for a character even
    after they disconnect and come back with a new client connection.

  Login-time asks (no owner entity) are tracked by client_id only and are
  not reconnectable — the player simply goes through the login flow again.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.InputState
  alias Pythelix.Task.Persistent, as: Task

  require Logger

  @cache :px_cache
  @cache_key :input_waiters

  # Cache value shape: %{by_client: %{client_id => task_id},
  #                      by_entity: %{entity_id_or_key => task_id}}

  @doc "Initialize the input waiters cache."
  def init do
    Cachex.put(@cache, @cache_key, %{by_client: %{}, by_entity: %{}})
  end

  @doc """
  Register a script as waiting for input.

  `entity_id_or_key` is nil for login-time asks (client entity, no owner).
  """
  @spec register(integer(), integer(), nil | integer() | String.t()) :: :ok
  def register(client_id, task_id, entity_id_or_key \\ nil) do
    waiters = get_waiters()

    waiters =
      put_in(waiters, [:by_client, client_id], task_id)

    waiters =
      if entity_id_or_key do
        put_in(waiters, [:by_entity, entity_id_or_key], task_id)
      else
        waiters
      end

    Cachex.put(@cache, @cache_key, waiters)
    :ok
  end

  @doc "Unregister a client from waiting for input."
  @spec unregister(integer()) :: :ok
  def unregister(client_id) do
    waiters = get_waiters()

    # Also remove the entity entry if this task owns one
    waiters =
      case Map.get(waiters.by_client, client_id) do
        nil ->
          waiters

        task_id ->
          entity_id_or_key =
            case Task.get(task_id) do
              %Task{script: %Script{input: %InputState{entity_id_or_key: key}}} -> key
              _ -> nil
            end

          if entity_id_or_key do
            update_in(waiters, [:by_entity], &Map.delete(&1, entity_id_or_key))
          else
            waiters
          end
      end

    waiters = update_in(waiters, [:by_client], &Map.delete(&1, client_id))
    Cachex.put(@cache, @cache_key, waiters)
    :ok
  end

  @doc "Return the task_id if this client has a script waiting for input, else nil."
  @spec waiting?(integer()) :: integer() | nil
  def waiting?(client_id) do
    Map.get(get_waiters().by_client, client_id)
  end

  @doc "Return the task_id if this entity has a script waiting for input, else nil."
  @spec waiting_for_entity?(integer() | String.t()) :: integer() | nil
  def waiting_for_entity?(entity_id_or_key) do
    Map.get(get_waiters().by_entity, entity_id_or_key)
  end

  @doc """
  Handle a reconnecting entity: update the waiting task with the new client
  connection, re-register, and re-send the prompt.

  Returns true if a pending task was found and updated, false otherwise.
  """
  @spec reconnect(integer() | String.t(), integer(), pid()) :: boolean()
  def reconnect(entity_id_or_key, new_client_id, new_pid) do
    case waiting_for_entity?(entity_id_or_key) do
      nil ->
        false

      task_id ->
        case Task.get(task_id) do
          nil ->
            # Task vanished — clean up stale entry
            waiters = get_waiters()
            waiters = update_in(waiters, [:by_entity], &Map.delete(&1, entity_id_or_key))
            Cachex.put(@cache, @cache_key, waiters)
            false

          task ->
            old_client_id = task.script.input.client_id
            new_input = %{task.script.input | client_id: new_client_id, client_pid: new_pid}
            new_script = %{task.script | input: new_input}
            Task.update(task_id, task.expire_at, :same, :same, new_script)

            # Replace client mapping (entity mapping stays the same)
            waiters = get_waiters()

            waiters =
              waiters
              |> update_in([:by_client], &Map.delete(&1, old_client_id))
              |> put_in([:by_client, new_client_id], task_id)

            Cachex.put(@cache, @cache_key, waiters)

            # Re-send prompt so player sees what they were being asked
            if new_input.prompt do
              Pythelix.Game.Hub.mark_client_with_message(new_client_id, new_input.prompt, new_pid)
            end

            true
        end
    end
  end

  @doc """
  Try to handle input for a waiting script.

  Returns :handled if input was consumed, :not_waiting otherwise.
  """
  @spec handle_input(integer(), String.t()) :: :handled | :not_waiting
  def handle_input(client_id, input) do
    case waiting?(client_id) do
      nil ->
        :not_waiting

      task_id ->
        case Task.get(task_id) do
          nil ->
            unregister(client_id)
            :not_waiting

          task ->
            process_input(task, client_id, input)
        end
    end
  end

  @doc """
  Reload input waiters from persistent tasks on startup or server restart.

  Registers tasks by entity only (client_ids from before the restart are
  stale). The client mapping will be populated when the player reconnects
  and `reconnect/3` is called from `handle_new_location`.
  """
  @spec reload() :: :ok
  def reload do
    Task.all()
    |> Enum.each(fn task ->
      case task do
        %Task{script: %Script{pause: :input, input: %InputState{} = input_state}} ->
          if input_state.entity_id_or_key do
            register(input_state.client_id, task.id, input_state.entity_id_or_key)
          end
          # Login-time asks (entity_id_or_key nil) are not reconnectable;
          # skip them — the player will go through login again.

        _ ->
          :ok
      end
    end)
  end

  # --- private ---

  defp process_input(task, client_id, input) do
    input_state = task.script.input

    case input_state do
      %InputState{choices: nil} ->
        resume_with_input(task, client_id, input)
        :handled

      %InputState{choices: choices, error_msg: error_msg, client_pid: pid} ->
        if input in choices do
          resume_with_input(task, client_id, input)
          :handled
        else
          Pythelix.Game.Hub.mark_client_with_message(client_id, error_msg, pid)
          :handled
        end
    end
  end

  defp resume_with_input(task, client_id, input) do
    unregister(client_id)

    Task.restore(task)
    resumed_script =
      %Script{task.script | pause: nil, input: nil, last_raw: input}
      |> Script.put_stack(input)

    Pythelix.Scripting.Runner.execute(resumed_script, task.code, task.name)
    Task.del(task.id)
  end

  defp get_waiters do
    case Cachex.get(@cache, @cache_key) do
      {:ok, nil} -> %{by_client: %{}, by_entity: %{}}
      {:ok, waiters} -> waiters
    end
  end
end
