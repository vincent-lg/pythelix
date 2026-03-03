defmodule Pythelix.Task.PersistentTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true

  alias Pythelix.Game.Hub
  alias Pythelix.Record
  alias Pythelix.Scripting.Runner
  alias Pythelix.Task.Persistent, as: Task

  setup_all do
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  # Reset task cache state between tests so IDs and status don't bleed across.
  setup do
    Task.init()
    :ok
  end

  # Helper: submit a sentinel job to the Hub and wait for it.
  # Because the Hub is sequential, receiving the sentinel guarantees all
  # previously enqueued jobs (including scheduled resume_task calls) have
  # finished running.
  defp await_hub(timeout \\ 1000) do
    test_pid = self()
    Hub.run(fn -> send(test_pid, :hub_done) end)
    assert_receive :hub_done, timeout
  end

  describe "resume_task/1 with entity_method action" do
    test "calls the named method on the entity with a fresh script" do
      {:ok, _} = Record.create_entity(key: "sched_mark")
      Record.set_method("sched_mark", "mark", :free, "self.was_called = True")

      task_id = System.unique_integer([:positive])
      Cachex.put(:px_tasks, task_id, %Task{
        id: task_id,
        expire_at: DateTime.utc_now(),
        name: "test:sched_mark:mark",
        action: {:entity_method, "sched_mark", "mark"}
      })

      Hub.run({Runner, :resume_task, [task_id]})
      await_hub()

      assert Record.get_attribute(Record.get_entity("sched_mark"), "was_called") == true
    end

    test "task is cleaned up from the cache after running" do
      {:ok, _} = Record.create_entity(key: "sched_cleanup")
      Record.set_method("sched_cleanup", "noop", :free, "")

      task_id = System.unique_integer([:positive])
      Cachex.put(:px_tasks, task_id, %Task{
        id: task_id,
        expire_at: DateTime.utc_now(),
        name: "test:sched_cleanup:noop",
        action: {:entity_method, "sched_cleanup", "noop"}
      })

      Hub.run({Runner, :resume_task, [task_id]})
      await_hub()

      assert Task.get(task_id) == nil
    end

    test "logs a warning and does not crash when the entity no longer exists" do
      task_id = System.unique_integer([:positive])
      Cachex.put(:px_tasks, task_id, %Task{
        id: task_id,
        expire_at: DateTime.utc_now(),
        name: "test:gone:mark",
        action: {:entity_method, "entity_that_does_not_exist", "mark"}
      })

      Hub.run({Runner, :resume_task, [task_id]})

      # No crash — the sentinel must still be processed
      await_hub()
    end
  end

  describe "add_entity_method/4 end-to-end" do
    test "schedules a task that fires and calls the entity method" do
      {:ok, _} = Record.create_entity(key: "sched_pipeline")
      Record.set_method("sched_pipeline", "trigger", :free, "self.triggered = True")

      # A past expire_at makes Task.Persistent schedule the timer at 0 ms.
      expire_at = DateTime.add(DateTime.utc_now(), -1, :second)
      Task.add_entity_method(expire_at, "test:sched_pipeline:trigger", "sched_pipeline", "trigger")

      # Give the 0 ms timer a moment to fire and enqueue the job on the Hub
      # before we enqueue our own sentinel.
      Process.sleep(20)
      await_hub()

      assert Record.get_attribute(Record.get_entity("sched_pipeline"), "triggered") == true
    end

    test "task entry is removed from the cache after firing" do
      {:ok, _} = Record.create_entity(key: "sched_del")
      Record.set_method("sched_del", "noop", :free, "")

      expire_at = DateTime.add(DateTime.utc_now(), -1, :second)
      task = Task.add_entity_method(expire_at, "test:sched_del:noop", "sched_del", "noop")

      Process.sleep(20)
      await_hub()

      assert Task.get(task.id) == nil
    end
  end
end
