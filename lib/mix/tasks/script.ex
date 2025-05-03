defmodule Mix.Tasks.Script do
  use Mix.Task

  @shortdoc "Interactive Pythelix script REPL"

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script

  def run(_args) do
    System.put_env("MIX_SCRIPT", "true")
    repo_config = Application.get_env(:pythelix, Pythelix.Repo) || []
    new_config = Keyword.put(repo_config, :log, false)
    Application.put_env(:pythelix, Pythelix.Repo, new_config)
    {:ok, _} = Application.ensure_all_started(:pythelix)
    IO.puts("Starting interactive script. Press CTRL+C twice to exit.")

    loop()
  end

  defp loop(script \\ nil) do
    input =
      case IO.gets(">>> ") do
        nil ->
          IO.puts("No input received. Exiting.")
          System.halt(0)

        raw_input ->
          String.trim(raw_input)
      end

    start_time = System.monotonic_time(:microsecond)
    script = handle_input(script, input)
    elapsed = System.monotonic_time(:microsecond) - start_time

    IO.puts("⏱️ Execution in #{elapsed} µs")
    loop(script)
  end

  defp handle_input(script, input) do
    line = (script && script.line + 1) && 1
    new_script = Scripting.run(input, call: false, line: line, repl: true)

    case script do
      nil ->
        new_script

      old_script ->
        %{old_script | bytecode: old_script.bytecode ++ new_script.bytecode, line: old_script.line + 1}
    end
    |> Scripting.Interpreter.Script.execute()
    |> then(fn
      %Script{stack: [value]} = script ->
        IO.inspect(value)

        %{script | stack: []}

      %Script{stack: []} = script ->
        script
    end)
  end
end
