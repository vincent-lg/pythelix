defmodule Pythelix.Scripting.RunnerTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Game.Hub
  alias Pythelix.{Record, Scripting}
  alias Pythelix.Scripting.{Runner, Traceback}

  setup_all do
    # Start the Game Hub for new system
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  def self_send(result, script, process \\ nil)

  def self_send(:ok, script, process) do
    process = process || self()
    send(process, {:result, script.last_raw})
  end

  def self_send(:error, script, process) do
    process = process || self()
    send(process, {:error, script.error})
  end

  describe "handle return" do
    test "asynchronous call with only one script" do
      code = "return 2 * 3"
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "unknown", step: {__MODULE__, :self_send})
      assert_receive {:result, 6}, 1000
    end

    test "asynchronous call with two methods calling each other" do
      {:ok, _} = Record.create_entity(key: "ent1")
      code = "return !ent2!.test2() + 5"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "return 2 * 4" )
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "unknown", step: {__MODULE__, :self_send})
      assert_receive {:result, 13}, 1000
    end

    test "asynchronous call with a pause and two methods calling each other" do
      {:ok, _ent1} = Record.create_entity(key: "ent1")
      code = "return !ent2!.test2() + 5"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "wait 1\nreturn 2 * 4" )
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "unknown", step: {__MODULE__, :self_send, [self()]})
      assert_receive {:result, 13}, 1200
    end

    test "asynchronous call with two pauses and three methods calling each other" do
      {:ok, _} = Record.create_entity(key: "ent1")
      code = "return !ent2!.test2() * 4"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "wait 0.1\nnum = !ent3!.test3() + 5\nwait 0.1\nreturn num")
      Record.create_entity(key: "ent3")
      Record.set_method("ent3", "test3", :free, "wait 0.2\nreturn 5")
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "unknown", step: {__MODULE__, :self_send, [self()]})
      assert_receive {:result, 40}, 500
    end
  end

  describe "handle errors" do
    test "asynchronous call with only one script" do
      code = "return 2 * X"
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "test", step: {__MODULE__, :self_send})
      assert_receive {:error, traceback}, 1000
      assert traceback.exception == NameError
      chain = Traceback.introspect(traceback)
      assert chain == [{"test", 1, "return 2 * X"}]
    end

    test "asynchronous call with no pause and two methods calling each other" do
      {:ok, _} = Record.create_entity(key: "ent1")
      code = "i = 0\nreturn !ent2!.test2() + 5"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "return 2 * X")
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "test1", step: {__MODULE__, :self_send, [self()]})
      assert_receive {:error, traceback}, 500
      assert traceback.exception == NameError
      assert length(traceback.chain) == 2
      [t1, t2] = Traceback.introspect(traceback)
      assert elem(t1, 1) == 2
      assert elem(t1, 2) == "return !ent2!.test2() + 5"
      assert elem(t2, 1) == 1
      assert elem(t2, 2) == "return 2 * X"
    end

    test "asynchronous call with a pause and two methods calling each other" do
      {:ok, _} = Record.create_entity(key: "ent1")
      code = "return !ent2!.test2() + 5"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "wait 0.2\nreturn 2 * X")
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "test1", step: {__MODULE__, :self_send, [self()]})
      assert_receive {:error, traceback}, 500
      assert traceback.exception == NameError
      assert length(traceback.chain) == 2
      [t1, t2] = Traceback.introspect(traceback)
      assert elem(t1, 1) == 1
      assert elem(t1, 2) == "return !ent2!.test2() + 5"
      assert elem(t2, 1) == 2
      assert elem(t2, 2) == "return 2 * X"
    end

    test "asynchronous call with multiple pauses and methods calling each other" do
      Record.create_entity(key: "ent1")
      code = "return !ent2!.test2() + 5"
      Record.set_method("ent1", "test1", :free, code)
      Record.create_entity(key: "ent2")
      Record.set_method("ent2", "test2", :free, "wait 0.1\nnum = !ent3!.test3()\nwait 0.1\nreturn num")
      Record.create_entity(key: "ent3")
      Record.set_method("ent3", "test3", :free, "wait 0.1\nreturn 2 + X")
      script = Scripting.run(code, call: false)
      Runner.run(script, code, "test1", step: {__MODULE__, :self_send, [self()]})
      assert_receive {:error, traceback}, 500
      assert traceback.exception == NameError
      assert length(traceback.chain) == 3
      [t1, t2, t3] = Traceback.introspect(traceback)
      assert elem(t1, 1) == 1
      assert elem(t1, 2) == "return !ent2!.test2() + 5"
      assert elem(t2, 1) == 2
      assert elem(t2, 2) == "num = !ent3!.test3()"
      assert elem(t3, 1) == 2
      assert elem(t3, 2) == "return 2 + X"
    end
  end
end
