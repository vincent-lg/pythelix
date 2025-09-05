defmodule Pythelix.Task.Script do
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting
  alias Pythelix.Scripting.{Runner, Store, Traceback}
  alias Pythelix.Task, as: PyTask

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

    pid = PyTask.wait_for_global(Pythelix.Game.Ext)

    if pid == nil do
      IO.puts("There's no running server to connect to, cannot continue.")
    else
      IO.puts("Starting interactive script. Press CTRL+C twice to exit.")

      repl(id, pid)
    end
  end

  defp repl(id, pid, variables \\ nil, buffer \\ nil) do
    variables = variables || %{}
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
          GenServer.cast(pid, {:run, {__MODULE__, :execute, [self(), input, variables]}})
          {nil, true}

        {:need_more, _} ->
          {input, false}

        {:error, reason} ->
          IO.puts(reason)
          {nil, false}
      end

    if need_wait do
      receive do
        {:result, result, variables} ->
          if result do
            IO.puts(result)
          end
          repl(id, pid, variables)

        {:error, traceback, variables} ->
          IO.puts(traceback)
          repl(id, pid, variables)
      end
    else
      repl(id, pid, variables, input)
    end
  end

  def execute(process, input, variables) do
    script =
      Scripting.run(input, call: false)
      |> then(& %{&1 | variables: variables})

    step = {__MODULE__, :handle_result, [process]}
    Runner.run(script, input, "<stdin>", step: step, sync: true)
  end

  def handle_result(:ok, script, process) do
    result =
      Store.get_value(script.last_raw)
      |> then(fn
        nil ->
          nil

        result ->
          Display.repr(script, result)
      end)

    variables = extract_variables(script)

    send(process, {:result, result, variables})
  end

  def handle_result(:error, script, process) do
    variables = extract_variables(script)

    send(process, {:error, Traceback.format(script.error), variables})
  end

  defp extract_variables(script) do
    script.variables
    |> Enum.map(fn {key, _} ->
      {key, Script.get_variable_value(script, key)}
    end)
    |> Map.new()
  end
end
