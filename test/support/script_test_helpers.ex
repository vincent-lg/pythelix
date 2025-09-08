defmodule Pythelix.ScriptTestHelpers do
  @moduledoc """
  Helper modules and functions for testing the remote script console.
  """

  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Traceback

  defmodule MockRemoteServer do
    @moduledoc """
    Mock remote server that simulates the game extension process.
    """
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(_opts) do
      {:ok, %{executed_scripts: [], responses: []}}
    end

    def handle_cast({:run, {module, :execute, [process, input, variables]}}, state) do
      # Simulate script execution
      apply(module, :execute, [process, input, variables])
      
      # Track executed scripts for testing
      new_state = %{state | executed_scripts: [{input, variables} | state.executed_scripts]}
      {:noreply, new_state}
    end

    def handle_call(:get_executed_scripts, _from, state) do
      {:reply, Enum.reverse(state.executed_scripts), state}
    end

    def handle_call({:set_response, response}, _from, state) do
      {:reply, :ok, %{state | responses: [response | state.responses]}}
    end

    def handle_call(:clear, _from, _state) do
      {:reply, :ok, %{executed_scripts: [], responses: []}}
    end

    def get_executed_scripts(server \\ __MODULE__) do
      GenServer.call(server, :get_executed_scripts)
    end

    def set_response(response, server \\ __MODULE__) do
      GenServer.call(server, {:set_response, response})
    end

    def clear(server \\ __MODULE__) do
      GenServer.call(server, :clear)
    end
  end

  defmodule MockTask do
    @moduledoc """
    Mock implementation of PyTask.wait_for_global/1 for testing.
    """

    @doc """
    Mock implementation that returns a predefined PID or nil.
    """
    def wait_for_global(_name) do
      case Process.get(:mock_global_pid) do
        nil -> spawn(fn -> :ok end)  # Return a dummy PID by default
        :not_found -> nil
        pid when is_pid(pid) -> pid
      end
    end

    @doc """
    Set the PID that wait_for_global/1 should return.
    """
    def set_global_pid(pid) do
      Process.put(:mock_global_pid, pid)
    end

    @doc """
    Set wait_for_global/1 to return nil (simulating no server).
    """
    def set_no_server do
      Process.put(:mock_global_pid, :not_found)
    end

    @doc """
    Clear the mock state.
    """
    def clear do
      Process.delete(:mock_global_pid)
    end
  end

  defmodule MockREPL do
    @moduledoc """
    Mock REPL parser for testing input parsing.
    """

    @doc """
    Parse input and return completion status.
    """
    def parse(input) do
      cond do
        String.ends_with?(String.trim(input), "\\") ->
          {:need_more, "Line continuation"}
        
        incomplete_brackets?(input) ->
          {:need_more, "Incomplete brackets"}
        
        String.trim(input) == "syntax_error" ->
          {:error, "Mock syntax error"}
        
        true ->
          :complete
      end
    end

    defp incomplete_brackets?(input) do
      open_parens = String.graphemes(input) |> Enum.count(&(&1 == "("))
      close_parens = String.graphemes(input) |> Enum.count(&(&1 == ")"))
      open_brackets = String.graphemes(input) |> Enum.count(&(&1 == "["))
      close_brackets = String.graphemes(input) |> Enum.count(&(&1 == "]"))
      
      open_parens != close_parens || open_brackets != close_brackets
    end
  end

  @doc """
  Create a mock script with the given properties.
  """
  def create_mock_script(opts \\ []) do
    defaults = %{
      id: "mock_script_#{:rand.uniform(1000)}",
      variables: %{},
      last_raw: nil,
      error: nil,
      line: 1
    }

    struct(Script, Map.merge(defaults, Map.new(opts)))
  end

  @doc """
  Create a mock traceback for testing.
  """
  def create_mock_traceback(opts \\ []) do
    defaults = %{
      exception: :test_error,
      message: "Mock error message",
      chain: [{create_mock_script(), "mock_code", "<test>"}]
    }

    struct(Traceback, Map.merge(defaults, Map.new(opts)))
  end

  @doc """
  Create a test process that collects messages for testing.
  """
  def create_test_collector do
    spawn(fn -> message_collector([]) end)
  end

  defp message_collector(messages) do
    receive do
      {:get_messages, sender} ->
        send(sender, {:messages, Enum.reverse(messages)})
        message_collector(messages)
        
      {:clear, sender} ->
        send(sender, :cleared)
        message_collector([])
        
      message ->
        message_collector([message | messages])
    end
  end

  @doc """
  Get messages collected by a test collector process.
  """
  def get_messages(collector_pid) do
    send(collector_pid, {:get_messages, self()})
    receive do
      {:messages, messages} -> messages
    after
      1000 -> []
    end
  end

  @doc """
  Clear messages from a test collector process.
  """
  def clear_messages(collector_pid) do
    send(collector_pid, {:clear, self()})
    receive do
      :cleared -> :ok
    after
      1000 -> :timeout
    end
  end

  @doc """
  Assert that a process receives a specific message within a timeout.
  """
  defmacro assert_receive_timeout(pattern, timeout \\ 1000) do
    quote do
      receive do
        unquote(pattern) -> :ok
      after
        unquote(timeout) -> 
          flunk("Expected to receive #{inspect(unquote(pattern))} within #{unquote(timeout)}ms")
      end
    end
  end
end