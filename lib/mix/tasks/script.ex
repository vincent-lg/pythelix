defmodule Mix.Tasks.Script do
  use Mix.Task

  @shortdoc "Interactive Pythelix script REPL"

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script

  def run(_args) do
    System.put_env("MIX_SCRIPT", "true")
    Application.put_env(:pythelix, :show_stats, false)
    repo_config = Application.get_env(:pythelix, Pythelix.Repo) || []
    new_config = Keyword.put(repo_config, :log, false)
    Application.put_env(:pythelix, Pythelix.Repo, new_config)
    {:ok, _} = Application.ensure_all_started(:pythelix)
    warmup()
    IO.puts("Starting interactive script. Press CTRL+C twice to exit.")

    loop()
  end

  defp loop(buffer \\ nil, script \\ nil) do
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

    {input, script} =
      case Pythelix.Scripting.REPL.parse(input) do
        :complete ->
          script = handle_input(script, input)
          {nil, script}

        {:need_more, _} ->
          {input, script}

        {:error, reason} ->
          IO.puts(reason)
          {nil, script}
      end

    loop(input, script)
  end

  defp handle_input(script, "/s") do
    IO.inspect(script)
  end

  defp handle_input(script, input) do
    line = (script && script.line + 1) && 1
    eval_start_time = System.monotonic_time(:microsecond)
    new_script = Scripting.run(input, call: false, line: line, repl: true)
    eval_elapsed = System.monotonic_time(:microsecond) - eval_start_time

    script =
      case script do
        nil ->
          new_script

        old_script ->
          %{old_script | bytecode: new_script.bytecode, line: old_script.line + 1, cursor: 0}
      end

    exec_start_time = System.monotonic_time(:microsecond)
    script = Scripting.Interpreter.Script.execute(script)
    exec_elapsed = System.monotonic_time(:microsecond) - exec_start_time
    IO.puts("⏱️ Parsed in #{eval_elapsed} µs, execution in #{exec_elapsed} µs")

    if script.last_raw != nil do
      IO.inspect(script.last_raw)
      %{script | last_raw: nil}
    else
      script
    end
  end

  defp warmup() do
    _ = Scripting.run("1 + 1", call: true, line: 1, repl: true)
    Pythelix.Record.warmup()
  end
end
