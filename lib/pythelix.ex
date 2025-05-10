defmodule Pythelix do
  @moduledoc """
  Pythelix keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  def force_test(number \\ 100) do
    {:ok, a} = Pythelix.Record.create_entity()
    {:ok, b} = Pythelix.Record.create_entity(location: a)
    {:ok, c} = Pythelix.Record.create_entity(location: b)
    {:ok, d} = Pythelix.Record.create_entity()

    start_time = System.monotonic_time(:microsecond)
    1..number
    |> Enum.reduce(d, fn _, old ->
      new = (old == b && d) || b
      Pythelix.Record.change_location(c, new)
      new
    end)
    elapsed = System.monotonic_time(:microsecond) - start_time
    IO.puts("Took #{elapsed} micro seconds.")
  end

  def v_force_test(number \\ 100) do
    {:ok, a} = Pythelix.Record.create_entity(virtual: true, key: "a")
    {:ok, b} = Pythelix.Record.create_entity(virtual: true, location: a, key: "b")
    {:ok, c} = Pythelix.Record.create_entity(virtual: true, location: b, key: "c")
    {:ok, d} = Pythelix.Record.create_entity(virtual: true, key: "d")

    start_time = System.monotonic_time(:microsecond)
    1..number
    |> Enum.reduce(d, fn _, old ->
      new = (old == b && d) || b
      Pythelix.Record.change_location(c, new)
      new
    end)
    elapsed = System.monotonic_time(:microsecond) - start_time
    IO.puts("Took #{elapsed} micro seconds.")
  end
end
