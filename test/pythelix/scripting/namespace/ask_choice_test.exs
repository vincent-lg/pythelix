defmodule Pythelix.Scripting.Namespace.AskChoiceTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Game.Hub
  alias Pythelix.Record
  alias Pythelix.Scripting.InputWaiter
  alias Pythelix.Scripting.Runner
  alias Pythelix.Task.Persistent

  setup_all do
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    Persistent.init()
    InputWaiter.init()

    # Create test generic/client entity with test namespace
    case Record.get_entity("test_generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "test_generic/client", virtual: true)

      _ ->
        :ok
    end

    Record.set_attribute(
      "test_generic/client",
      "msg",
      {:extended, Pythelix.Test.TestClientNamespace, :m_msg}
    )

    Record.set_attribute(
      "test_generic/client",
      "disconnect",
      {:extended, Pythelix.Test.TestClientNamespace, :m_disconnect}
    )

    Record.set_attribute(
      "test_generic/client",
      "owner",
      {:extended_property, Pythelix.Test.TestClientNamespace, :owner}
    )

    test_generic_client = Record.get_entity("test_generic/client")

    {:ok, client} =
      Record.create_entity(key: "test_client", virtual: true, parent: test_generic_client)

    Record.set_attribute("test_client", "client_id", 999)
    Record.set_attribute("test_client", "pid", self())

    {:ok, client: client}
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

  # Helper to simulate user input through the hub
  defp simulate_input(client_id, input) do
    Hub.run(fn -> InputWaiter.handle_input(client_id, input) end)
  end

  describe "ask" do
    test "ask pauses script and resumes with input", %{client: _client} do
      code = """
      name = ask(!test_client!, prompt="What is your name?")
      return name
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "ask_test", step: {__MODULE__, :self_send, [self()]})

      # Should receive the prompt
      assert_receive {:message, "What is your name?"}, 1000

      # Script should be waiting for input
      Process.sleep(100)
      assert InputWaiter.waiting?(999) != nil

      # Simulate user input
      simulate_input(999, "Alice")

      # Should receive the result
      assert_receive {:result, "Alice"}, 1000
    end

    test "ask without prompt", %{client: _client} do
      code = """
      name = ask(!test_client!)
      return name
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "ask_test", step: {__MODULE__, :self_send, [self()]})

      # Give time for the script to pause
      Process.sleep(200)

      # Script should be waiting for input
      assert InputWaiter.waiting?(999) != nil

      # Simulate user input
      simulate_input(999, "Bob")

      assert_receive {:result, "Bob"}, 1000
    end

    test "ask with timeout returns None", %{client: _client} do
      code = """
      name = ask(!test_client!, prompt="Quick!", timeout=0.5)
      return name
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "ask_test", step: {__MODULE__, :self_send, [self()]})

      # Should receive the prompt
      assert_receive {:message, "Quick!"}, 1000

      # Script should be waiting for input
      Process.sleep(100)
      assert InputWaiter.waiting?(999) != nil

      # Don't send any input - wait for timeout
      assert_receive {:result, :none}, 2000
    end

    test "ask returns None when entity has no client", %{client: _client} do
      # Create an entity that's not a client and has no controlling client
      {:ok, _entity} = Record.create_entity(key: "lonely_npc", virtual: true)

      code = """
      result = ask(!lonely_npc!)
      return result
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "ask_test", step: {__MODULE__, :self_send, [self()]})

      assert_receive {:result, :none}, 1000
    end
  end

  describe "choice" do
    test "choice accepts valid input and returns mapped value", %{client: _client} do
      code = """
      choices = {"yes": True, "no": False}
      answer = choice(!test_client!, choices, prompt="Are you sure?", retry="Please answer yes or no.")
      return answer
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "choice_test", step: {__MODULE__, :self_send, [self()]})

      # Should receive the prompt
      assert_receive {:message, "Are you sure?"}, 1000

      # Script should be waiting
      Process.sleep(100)
      assert InputWaiter.waiting?(999) != nil

      # Send valid input — returns the mapped value (True)
      simulate_input(999, "yes")

      assert_receive {:result, true}, 1000
    end

    test "choice rejects invalid input and re-asks", %{client: _client} do
      code = """
      choices = {"yes": True, "no": False}
      answer = choice(!test_client!, choices, retry="Please answer yes or no.")
      return answer
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "choice_test", step: {__MODULE__, :self_send, [self()]})

      # Give time for the script to pause
      Process.sleep(200)

      # Send invalid input
      simulate_input(999, "maybe")

      # Should receive retry message
      assert_receive {:message, "Please answer yes or no."}, 1000

      # Script should still be waiting
      Process.sleep(100)
      assert InputWaiter.waiting?(999) != nil

      # Send valid input — returns the mapped value (False)
      simulate_input(999, "no")

      assert_receive {:result, false}, 1000
    end

    test "choice with numeric keys returns correct value", %{client: _client} do
      code = """
      choices = {"1": "blue", "2": "green", "3": "orange"}
      color = choice(!test_client!, choices, prompt="Pick a color:\\n1. Blue\\n2. Green\\n3. Orange", retry="Invalid choice.")
      return color
      """

      script = Pythelix.Scripting.run(code, call: false)
      Runner.run(script, code, "choice_test", step: {__MODULE__, :self_send, [self()]})

      assert_receive {:message, _}, 1000

      Process.sleep(100)
      assert InputWaiter.waiting?(999) != nil

      simulate_input(999, "2")

      assert_receive {:result, "green"}, 1000
    end
  end
end
