defmodule Pythelix.Task.Script do
  alias Pythelix.Task

  def run() do
    id = :crypto.strong_rand_bytes(4) |> Base.encode16()
    id = "console_#{id}"

    if Node.alive?() == false do
      Node.start(String.to_atom("#{id}@127.0.0.1"))
      Node.set_cookie(:mycookie)
    end

    topologies = Application.get_env(:libcluster, :topologies)

    # Start libcluster manually
    {:ok, _pid} = Supervisor.start_link(
      [
        {Cluster.Supervisor, [topologies, [name: __MODULE__.ClusterSupervisor]]}
      ],
      strategy: :one_for_one
    )

    pid = Task.wait_for_global(Pythelix.Command.Hub)

    if pid == nil do
      IO.puts("There's no running server to connect to, cannot continue.")
    else
      IO.puts("Starting interactive script. Press CTRL+C twice to exit.")

      GenServer.cast({:global, Pythelix.Command.Hub}, {:start, id, %{script: nil, pid: self()}, Pythelix.Scripting.REPL.Executor})
      loop(id)
    end
  end

  defp loop(id, buffer \\ nil) do
    input =
      case IO.gets((buffer && "... ") || ">>> ") do
        nil ->
          IO.puts("No input received. Exiting.")
          System.halt(0)

        raw_input ->
          String.trim(raw_input)
      end

    input =
      if buffer do
        "#{buffer}\n#{input}"
      else
        input
      end

    {input, need_wait} =
      case Pythelix.Scripting.REPL.parse(input) do
        :complete ->
          GenServer.cast({:global, Pythelix.Command.Hub}, {:send_task, id, {:input, input}})
          {nil, true}

        {:need_more, _} ->
          {input, false}

        {:error, reason} ->
          IO.puts(reason)
          {nil, false}
      end

    if need_wait do
      receive do
        {:text, output} ->
          IO.puts(output)

        {:text, output, eval_elapsed, exec_elapsed, apply_elapsed} ->
          IO.puts("⏱️ Parsed in #{eval_elapsed} µs, execution in #{exec_elapsed} µs, applied in #{apply_elapsed} µs")

          if output != nil do
            IO.puts(output)
          end
      end
    end

    loop(id, input)
  end
end
