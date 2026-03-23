defmodule Pythelix.Scripting.Namespace.Console do
  @moduledoc """
  Namespace for Console REPL objects.

  Provides methods to feed code line by line, check completeness,
  and execute accumulated code while retaining variables.
  """

  use Pythelix.Scripting.Namespace

  alias Pythelix.Scripting
  alias Pythelix.Scripting.Interpreter.Script
  alias Pythelix.Scripting.Object.{Console, Dict}
  alias Pythelix.Scripting.{Display, REPL, Runner, Traceback}

  defattr buffer(_script, self) do
    %Console{buffer: buffer} = Store.get_value(self)
    buffer || :none
  end

  defattr variables(_script, self) do
    %Console{variables: variables} = Store.get_value(self)
    variables_to_dict(variables)
  end

  defmet push(script, namespace), [
    {:text, index: 0, keyword: "text", type: :str}
  ] do
    text = Store.get_value(namespace.text)
    console = Store.get_value(namespace.self)

    buffer =
      case console.buffer do
        nil -> text
        existing -> existing <> "\n" <> text
      end

    case REPL.parse(buffer) do
      :complete ->
        execute_buffer(script, namespace.self, console, buffer)

      {:need_more, _reason} ->
        Store.update_reference(namespace.self, %{console | buffer: buffer})
        make_result(script, "need_more", :none, :none)

      {:error, reason} ->
        Store.update_reference(namespace.self, %{console | buffer: nil})
        make_result(script, "error", :none, reason)
    end
  end

  defmet reset(script, namespace), [] do
    console = Store.get_value(namespace.self)
    Store.update_reference(namespace.self, %{console | buffer: nil})
    {script, :none}
  end

  defmet clear(script, namespace), [] do
    Store.update_reference(namespace.self, %Console{})
    {script, :none}
  end

  defmet __repr__(script, namespace), [] do
    console = Store.get_value(namespace.self)
    var_count = map_size(console.variables)
    has_buffer = if console.buffer, do: ", buffered", else: ""
    {script, "<Console (#{var_count} vars#{has_buffer})>"}
  end

  # Execute the buffer via the Runner so pauses are properly handled.
  defp execute_buffer(script, self_ref, console, buffer) do
    sub_script = Scripting.run(buffer, call: false)

    case sub_script do
      %Script{error: %Traceback{} = traceback} ->
        Store.update_reference(self_ref, %{console | buffer: nil})
        error_msg = Traceback.format(traceback)
        make_result(script, "error", :none, error_msg)

      sub_script ->
        sub_script =
          sub_script
          |> restore_variables(console.variables)
          |> Script.set_step(__MODULE__, :on_console_complete, [script, self_ref])

        # Mark as pending so the step can detect synchronous completion.
        sync_key = {__MODULE__, script.id}
        Process.put(sync_key, :pending)

        # Execute ourselves first so we can intercept Erlang exceptions
        # (e.g. ArithmeticError from 1/0) that Runner.execute would swallow
        # without calling the step.
        executed =
          try do
            Script.execute(sub_script, buffer, "<console>")
          rescue
            e ->
              Script.destroy(sub_script)
              Store.update_reference(self_ref, %{console | buffer: nil})
              Process.put(sync_key, {:done, "error", :none, Exception.message(e)})
              :erlang_error
          end

        if executed != :erlang_error do
          Runner.execute(executed, buffer, "<console>")
        end

        case Process.delete(sync_key) do
          :pending ->
            # Step has not run yet — sub_script is suspended (async pause).
            {%{script | pause: :wait_child}, :none}

          {:done, status, value, error} ->
            # Step ran synchronously — return the result directly.
            make_result(script, status, value, error)
        end
    end
  end

  @doc false
  def on_console_complete(:ok, completed_script, outer_script, self_ref) do
    console = Store.get_value(self_ref)

    value =
      Store.get_value(completed_script.last_raw)
      |> then(fn
        nil -> :none
        :none -> :none
        result -> Display.repr(outer_script, result)
      end)

    variables = extract_variables(completed_script)
    Store.update_reference(self_ref, %{console | buffer: nil, variables: variables})

    deliver_result(outer_script, "complete", value, :none)
  end

  def on_console_complete(:error, failed_script, outer_script, self_ref) do
    console = Store.get_value(self_ref)
    variables = extract_variables(failed_script)
    Store.update_reference(self_ref, %{console | buffer: nil, variables: variables})

    error_msg = Traceback.format(failed_script.error)
    deliver_result(outer_script, "error", :none, error_msg)
  end

  # Deliver the result to the outer script.
  # If the process dict still holds the :pending marker, the step is running
  # synchronously inside Runner.run — store the result there so execute_buffer
  # can pick it up and return it directly without pausing.
  # Otherwise the outer script is already suspended (async pause) and must be
  # resumed explicitly via Runner.execute.
  defp deliver_result(outer_script, status, value, error) do
    sync_key = {__MODULE__, outer_script.id}

    case Process.get(sync_key) do
      :pending ->
        Process.put(sync_key, {:done, status, value, error})

      _ ->
        {outer_script, result_ref} = make_result(outer_script, status, value, error)

        %{outer_script | pause: nil}
        |> Script.put_stack(result_ref)
        |> Runner.execute(outer_script.code, outer_script.name)
    end
  end

  defp make_result(script, status, value, error) do
    dict =
      Dict.new()
      |> Dict.put("status", status)
      |> Dict.put("value", value)
      |> Dict.put("error", error)

    {script, ref} = Script.reference(script, dict)
    {script, ref}
  end

  defp extract_variables(result_script) do
    result_script.variables
    |> Enum.map(fn {key, _} ->
      {key, Script.get_variable_value(result_script, key)}
    end)
    |> Map.new()
  end

  defp restore_variables(sub_script, variables) do
    Enum.reduce(variables, sub_script, fn {key, value}, acc ->
      {acc, value} =
        if Script.references?(value) do
          Script.reference(acc, value)
        else
          {acc, value}
        end

      Script.store(acc, key, value)
    end)
  end

  defp variables_to_dict(variables) do
    Enum.reduce(variables, Dict.new(), fn {key, value}, dict ->
      Dict.put(dict, key, value)
    end)
  end
end
