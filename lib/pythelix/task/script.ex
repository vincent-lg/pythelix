defmodule Pythelix.Task.Script do
  alias Pythelix.Scripting.Display
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting
  alias Pythelix.Scripting.{Runner, Store, Traceback}

  @console Pythelix.Adapters.Console
  @cluster Pythelix.Adapters.ClusterCtl

  def run(console \\ @console, cluster \\ @cluster) do
    id = "console_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16())

    :ok = cluster.ensure_node_started(id)
    {:ok, _pid} = cluster.start_cluster()

    pid = cluster.wait_for_global(Pythelix.Game.Ext, 2000, 50)

    if pid == nil do
      console.puts("There's no running server to connect to, cannot continue.")
      console.halt(0)
    else
      console.puts("Starting interactive script. Press CTRL+C twice to exit.")

      repl(id, pid, console)
    end
  end

  defp repl(id, pid, console, variables \\ nil, buffer \\ nil) do
    variables = variables || %{}
    input =
      case console.gets((buffer && "... ") || ">>> ") do
        nil ->
          console.puts("No input received. Exiting.")
          console.halt(0)

        :stop ->
          :stop

        raw_input ->
          String.trim(raw_input)
      end

    handle_input(id, pid, console, input, buffer, variables)
  end

  def handle_input(_, _, _, :stop, _, _), do: :ok
  def handle_input(id, pid, console, input, buffer, variables) do
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
          console.puts(reason)
          {nil, false}
      end

    if need_wait do
      receive do
        {:result, result, variables} ->
          if result do
            console.puts(result)
          end
          repl(id, pid, console, variables)

        {:error, traceback, variables} ->
          console.puts(traceback)
          repl(id, pid, console, variables)
      end
    else
      repl(id, pid, console, variables, input)
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
