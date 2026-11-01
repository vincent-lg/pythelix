defmodule Pythelix.Game.Clock.VirtualTest do
  use ExUnit.Case, async: false

  alias Pythelix.Game.Clock
  alias Pythelix.Game.Clock.Virtual

  # Re-arms itself on every :tick, the way the tick manager does.
  defmodule Ticker do
    use GenServer

    def start_link(test), do: GenServer.start_link(__MODULE__, test)

    def init(test) do
      Virtual.send_after(self(), :tick, 100)
      {:ok, %{test: test, count: 0}}
    end

    def handle_info(:tick, state) do
      send(state.test, {:ticked, state.count + 1})
      Virtual.send_after(self(), :tick, 100)
      {:noreply, %{state | count: state.count + 1}}
    end
  end

  setup do
    start_supervised!(Virtual)
    previous = Application.get_env(:pythelix, :clock)
    Application.put_env(:pythelix, :clock, Virtual)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:pythelix, :clock)
        clock -> Application.put_env(:pythelix, :clock, clock)
      end
    end)

    :ok
  end

  test "time stands still until advanced" do
    assert Virtual.now_ms() == 0
    Process.sleep(5)
    assert Virtual.now_ms() == 0

    assert :ok = Clock.advance(1_500)
    assert Virtual.now_ms() == 1_500
  end

  test "a timer fires only once the clock has reached it" do
    Virtual.send_after(self(), :later, 1_000)

    Clock.advance(999)
    refute_received :later

    Clock.advance(1)
    assert_received :later
  end

  test "timers fire in due order, and now reads as their due time when they do" do
    test = self()
    Virtual.send_after(test, :second, 200)
    Virtual.send_after(test, :first, 100)
    Virtual.send_after(test, :third, 300)

    Clock.advance(1_000)

    assert {:messages, [:first, :second, :third]} = Process.info(test, :messages)
  end

  test "a timer armed by a fired timer is honoured in the same pass" do
    start_supervised!({Ticker, self()})

    Clock.advance(350)

    assert_received {:ticked, 1}
    assert_received {:ticked, 2}
    assert_received {:ticked, 3}
    refute_received {:ticked, 4}
  end

  test "a cancelled timer never fires" do
    ref = Virtual.send_after(self(), :never, 100)
    assert Virtual.cancel_timer(ref) == 100
    assert Virtual.cancel_timer(ref) == false

    Clock.advance(1_000)
    refute_received :never
  end

  test "there is no jitter" do
    assert Virtual.jitter(60_000) == 0
  end

  test "the real clock cannot be hurried" do
    assert Clock.Real.advance(1_000) == {:error, :real_clock}
  end
end
