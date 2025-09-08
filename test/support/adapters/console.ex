defmodule Test.Pythelix.Adapters.Console do
  @behaviour Pythelix.Ports.Console
  def start_link, do: Agent.start_link(fn -> %{out: [], in: :queue.new()} end, name: __MODULE__)
  def feed_input(s) do
    Agent.update(__MODULE__, fn up -> update_in(up.in, &:queue.in(s, &1)) end)
  end

  def outputs do
    Agent.get_and_update(__MODULE__, fn st ->
      {Enum.reverse(st.out), %{st | out: []}}
    end)
  end

  def puts(msg), do: Agent.update(__MODULE__, &update_in(&1.out, fn out -> [IO.iodata_to_binary(msg) | out] end))
  def gets(prompt) do
    puts(prompt)
    Agent.get_and_update(__MODULE__, fn st ->
      case :queue.out(st.in) do
        {{:value, x}, q} ->
          {x, %{st | in: q}}

        {:empty, _} ->
          {:stop, st}
      end
    end)
  end

  def halt(_code) do
    ""
    #IO.puts("Exitting")
    #exit(:halted)
  end
end
