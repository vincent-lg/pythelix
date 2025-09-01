defmodule Pythelix.Game.Hub do
  @moduledoc """
  The game HUB, responsible for queueing tasks (all inputs)
  and exeucing them one at a time.
  """
  alias Pythelix.{Method, Record, World}
  alias Pythelix.Task.Persistent

  @behaviour :gen_statem

  def callback_mode, do: [:state_functions, :state_enter]

  # Public API
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    :gen_statem.start_link({:local, name}, __MODULE__, opts, [])
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Submit a job in the task queue.

  The job can either be:
    A 0-arity function
    A module (its `:execute` function will be called).
    A tuple ({M, F, A}).
  """
  def run(job, server \\ __MODULE__), do: :gen_statem.cast(server, {:run, job})

  @doc """
  Mark a client as having unsent messages and forward the message immediately.
  """
  def mark_client_with_message(client_id, message, pid, server \\ __MODULE__) do
    :gen_statem.cast(server, {:message, client_id, message, pid})
  end

  # Init
  def init(opts) do
    {:ok, :init, %{
      job_pid: nil,
      mon_ref: nil,
      ticket: nil,
      max_ms: Keyword.get(opts, :max_ms, 2_000),
      clients_with_messages: MapSet.new()
    }}
  end

  # INIT state
  def init(:enter, _old_state, data) do
    init_world()
    #{:next_state, :idle, data}
    {:keep_state, data, [{:state_timeout, 0, :go_idle}]}
  end

  def init(:state_timeout, :go_idle, data) do
    {:next_state, :idle, data}
  end

  # IDLE state
  def idle(:cast, {:run, job}, data) do
    ticket = make_ref()
    server = self()

    {:ok, pid} =
      Task.Supervisor.start_child(Pythelix.Game.TaskSupervisor, fn ->
        result = run_job(job)            # your MFA/fun wrapper
        send(server, {:job_ok, ticket, result})
      end)

    mon = Process.monitor(pid)

    actions =
      case data.max_ms do
        :infinity -> []
        ms when is_integer(ms) -> [{:state_timeout, ms, :job_timed_out}]
      end

    {:next_state, :busy, %{data | job_pid: pid, mon_ref: mon, ticket: ticket}, actions}
  end

  def idle(:cast, {:message, client_id, message, pid}, data) do
    {:keep_state, handle_message(client_id, message, pid, data)}
  end

  def idle(_type, _event, data), do: {:keep_state, data}

  # BUSY state
  def busy(:cast, {:run, _job}, _data), do: {:keep_state_and_data, [:postpone]}

  def busy(:info, {:job_ok, ticket, _result}, %{ticket: ticket, mon_ref: mon} = data) do
    Process.demonitor(mon, [:flush])
    data = send_prompts_to_clients_with_messages(data)
    {:next_state, :idle, %{data | job_pid: nil, mon_ref: nil, ticket: nil}}
  end

  # Anything else (crash, kill, or "no ok sent"): rely on :DOWN to recover
  def busy(:info, {:DOWN, mon, :process, _pid, _reason}, %{mon_ref: mon} = data) do
    data = send_prompts_to_clients_with_messages(data)
    {:next_state, :idle, %{data | job_pid: nil, mon_ref: nil, ticket: nil}}
  end

  def busy(:state_timeout, :job_timed_out, %{job_pid: pid}) do
    if is_pid(pid) and Process.alive?(pid), do: Process.exit(pid, :kill)
    {:keep_state_and_data, []}
  end

  def busy(:cast, {:message, client_id, message, pid}, data) do
    {:keep_state, handle_message(client_id, message, pid, data)}
  end

  def busy(_type, _event, data), do: {:keep_state, data}

  defp run_job(fun) when is_function(fun, 0), do: fun.()

  defp run_job(m) when is_atom(m) do
    apply(m, :execute, [])
  end

  defp run_job({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
  end

  defp run_job(arg) do
    raise "invalid task: #{inspect(arg)}"
  end

  defp handle_message(client_id, message, pid, data) do
    # Forward message immediately and mark client as having messages
    send(pid, {:message, message})
    clients_with_messages = MapSet.put(data.clients_with_messages, client_id)
    %{data | clients_with_messages: clients_with_messages}
  end

  defp send_prompts_to_clients_with_messages(data) do
    Enum.reduce(data.clients_with_messages, data, fn client_id, acc ->
      send_prompt_to_client(client_id, acc)
    end)
  end

  defp send_prompt_to_client(client_id, data) do
    key = "client/#{client_id}"

    case Record.get_entity(key) do
      nil ->
        # Client no longer exists, remove from set
        clients_with_messages = MapSet.delete(data.clients_with_messages, client_id)
        %{data | clients_with_messages: clients_with_messages}

      client ->
        menu = Record.get_location_entity(client)

        prompt =
          case menu do
            nil ->
              ""
            menu ->
              try do
                Method.call_entity(menu, "get_prompt", [client])
              rescue
                _exception ->
                  ""
              end
          end

        pid = Record.get_attribute(client, "pid")
        send(pid, {:full, prompt})

        # Remove client from set after sending prompt
        clients_with_messages = MapSet.delete(data.clients_with_messages, client_id)
        %{data | clients_with_messages: clients_with_messages}
    end
  end

  defp init_world() do
    Record.Diff.init()
    Record.cache_relationships()
    init_start_time = System.monotonic_time(:microsecond)

    if Application.get_env(:pythelix, :worldlets) do
      World.init()
      init_elapsed = System.monotonic_time(:microsecond) - init_start_time
      if Application.get_env(:pythelix, :show_stats) do
        IO.puts("⏱️ World initialized in #{init_elapsed} µs")
      end

      :ok
    end
    |> tap(fn _ ->
      tasks_start_time = System.monotonic_time(:microsecond)
      Persistent.init()
      number = Persistent.load()
      tasks_elapsed = System.monotonic_time(:microsecond) - tasks_start_time
      if Application.get_env(:pythelix, :show_stats) do
        IO.puts("⏱️ #{number} tasks were loaded in #{tasks_elapsed} µs")
      end
    end)
  end
end
