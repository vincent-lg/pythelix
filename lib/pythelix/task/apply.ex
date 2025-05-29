defmodule Pythelix.Task.Apply do
  alias Pythelix.Task
  alias Pythelix.World

  def run([]) do
    run([:all])
  end

  def run("") do
    run([:all])
  end

  def run(str) when is_binary(str) do
    run(OptionParser.split(str))
  end

  def run([file]) do
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
      IO.puts("Applying a worldlet directory or file...")

      GenServer.cast({:global, Pythelix.Command.Hub}, {:start, id, %{file: file, pid: self()}, World.Executor})

      receive do
        {:ok, path, number} ->
          IO.puts("Worldlet applied from #{path}: #{number} entities were added or updated.")

        :nofile ->
          IO.puts("The specified file #{inspect(file)} doesn't exist.")

        :error ->
          IO.puts("An error occurred, applying cancelled.")
      end
    end
  end

  def run(_) do
    IO.puts("Please specify which worldlet directory or file to apply.")
  end
end
