defmodule Pythelix.Game.HubFastTest do
  use Pythelix.DataCase, async: false  # Hub spawns processes that need DB access

  @moduletag capture_log: true

  alias Pythelix.Game.Hub

  setup_all do
    # Start the Game Hub
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  setup _tags do
    Pythelix.Scripting.Store.init()
    Pythelix.Record.Cache.clear()
    srv = :"hub_test_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Hub, name: srv, max_ms: 60})
    [srv: srv]
  end

  defp mk_job(test_pid, id, sleep_ms) do
    fn ->
      send(test_pid, {:started, id})
      if sleep_ms > 0, do: :timer.sleep(sleep_ms)
      send(test_pid, {:done, id})
    end
  end

  defp mk_job_with_barrier(test_pid, id, sleep_ms) do
    fn ->
      send(test_pid, {:started, id})
      if sleep_ms > 0, do: :timer.sleep(sleep_ms)
      ref = make_ref()
      # include our pid so the test can ack us directly
      send(test_pid, {:done, id, ref, self()})
      receive do
        {:ack, ^ref} -> :ok
      after
        1_000 -> :ok  # fail-safe so a broken test won’t deadlock forever
      end
    end
  end

  defp crash_job(test_pid, id) do
    fn ->
      send(test_pid, {:started, id})
      raise "boom: #{inspect(id)}"
    end
  end

  test "second job waits while busy", %{srv: srv} do
    p = self()

    slow = mk_job_with_barrier(p, :slow, 40)
    next = mk_job_with_barrier(p, :next, 40)

    Hub.run(slow, srv)
    Hub.run(next, srv)

    # 1) Slow starts first
    assert_receive {:started, :slow}, 10

    # 2) While slow is ‘running’, next must not start
    refute_receive {:started, :next}, 10

    # 3) Slow reaches its 'done' point, but is blocked waiting for our ack
    assert_receive {:done, :slow, ref, slow_pid}, 40

    # 4) Even now, next must *still* not start (we haven't acked → Hub can't progress)
    refute_receive {:started, :next}, 10

    # 5) Release slow → job returns → Hub gets {:job_ok,...} → next starts
    send(slow_pid, {:ack, ref})

    assert_receive {:started, :next}, 200
    assert_receive {:done,    :next, next_ref, next_pid}, 300
    # tidy up the barrier for the 'next' job too
    send(next_pid, {:ack, next_ref})
  end

  test "all jobs eventually run", %{srv: srv} do
    p = self()
    for i <- 1..20, do: Hub.run(mk_job(p, i, 3), srv)

    got =
      for _ <- 1..20 do
        assert_receive {:done, id}, 500
        id
      end

    assert Enum.sort(got) == Enum.to_list(1..20)
  end

  test "timeout frees slot; next job runs", %{srv: srv} do
    p = self()
    slow = fn -> send(p, {:started, :slow}); :timer.sleep(5_000) end
    fast = mk_job(p, :fast, 5)

    Hub.run(slow, srv)
    Hub.run(fast, srv)

    assert_receive {:started, :slow}, 80
    # max_ms=60 → slow is killed quickly; fast should complete < 300ms overall
    assert_receive {:done, :fast}, 300
    refute_receive {:done, :slow}, 100
  end

  test "crash does not block next job", %{srv: srv} do
    p = self()
    Hub.run(crash_job(p, :crash), srv)
    Hub.run(mk_job(p, :next, 10), srv)

    assert_receive {:started, :crash}, 80
    assert_receive {:started, :next},  200
    assert_receive {:done,    :next},  200
    refute_receive {:done, :crash},    50
  end

  test "crash storm still lets successes through", %{srv: srv} do
    p = self()
    for i <- 1..10 do
      if rem(i, 2) == 0, do: Hub.run(mk_job(p, {:ok, i}, 5), srv),
                        else: Hub.run(crash_job(p, {:crash, i}), srv)
    end

    got =
      for _ <- 1..5 do
        assert_receive {:done, {:ok, i}}, 800
        i
      end

    assert Enum.sort(got) == Enum.to_list(2..10//2)
  end
end
