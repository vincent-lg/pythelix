defmodule Pythelix.Scenario do
  @moduledoc """
  Scenarios: what should happen, written the way it looks in a MUD client.

  A scenario is a transcript. It says who is where, what they type and what
  each of them then sees — and running it checks that the game really behaves
  that way:

      apply worldlets/farm

      given Alice in !farm/room/field!
      given Bob in !farm/room/field!

      Alice> harvest wheat
      Alice sees "You harvest a bundle of wheat."
      Bob sees "Alice bends down and harvests some wheat."

      Alice> harvest wheat
      Alice sees "There is nothing left to harvest."
      Bob does not see "bundle of wheat"

  The vocabulary is deliberately tiny and closed — five constructs, listed
  below. It is not a test framework and has no expressions, variables or
  conditions: the moment it becomes programmable it stops being readable by
  the people it is for, and stops being reliably writable by an assistant.

  ## The five constructs

    * `apply <path>` — apply a worldlet file or directory before playing.
      Optional and repeatable; with none, the game's own worldlets are used.
    * `given <Name> in !<entity key>!` — a player of that name, in that room,
      already logged in.
    * `<Name>> <input>` — that player types that line.
    * `<Name> sees "<text>"` — that text reached them since they last typed.
    * `<Name> does not see "<text>"` — it didn't.

  Text is matched as a substring, so a scenario survives a reworded sentence
  around it, a prompt or a colour code. Lines starting with `#` are comments,
  and blank lines separate exchanges for readability.
  """

  alias Pythelix.Scenario.Step

  defstruct [:name, :file, steps: []]

  @type t :: %__MODULE__{
          name: binary(),
          file: binary() | nil,
          steps: [Step.t()]
        }

  @doc """
  Read and parse a scenario file.

  Returns `{:ok, scenario}`, or `{:error, diagnostics}` listing every line
  that isn't one of the five constructs — all of them, since a typo on one
  line says nothing about the next.
  """
  @spec parse_file(binary()) :: {:ok, t()} | {:error, [Step.error()]}
  def parse_file(path) do
    path
    |> Pythelix.Encoding.read_file!()
    |> parse(name: Path.basename(path, Path.extname(path)), file: path)
  end

  @doc """
  Parse scenario text. See `parse_file/1`.
  """
  @spec parse(binary(), keyword()) :: {:ok, t()} | {:error, [Step.error()]}
  def parse(text, opts \\ []) do
    {steps, errors} =
      text
      |> String.split(~r/\r?\n/)
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {line, number}, {steps, errors} ->
        case Step.parse(line, number) do
          :skip -> {steps, errors}
          {:ok, step} -> {[step | steps], errors}
          {:error, error} -> {steps, [error | errors]}
        end
      end)

    case Enum.reverse(errors) do
      [] ->
        {:ok,
         %__MODULE__{
           name: Keyword.get(opts, :name, "scenario"),
           file: Keyword.get(opts, :file),
           steps: Enum.reverse(steps)
         }}

      errors ->
        {:error, errors}
    end
  end
end
