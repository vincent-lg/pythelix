defmodule Pythelix.World.TracebackLocationTest do
  @moduledoc """
  A traceback should send the builder to the worldlet, not to the method.

  "`greet`, line 3" tells you which method failed; "`!animal!.greet`, defined
  in `worldlets/animals.txt`, line 21" tells you where to open your editor.
  """

  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :tmp_dir

  alias Pythelix.Game.Hub
  alias Pythelix.{Method, Paths, Record, Scripting}
  alias Pythelix.Scripting.{Runner, Traceback}

  setup_all do
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  def self_send(:ok, script, process), do: send(process, {:result, script.last_raw})
  def self_send(:error, script, process), do: send(process, {:error, script.error})

  defp write(dir, name, content) do
    path = Path.join(dir, name)
    File.write!(path, content)

    path
  end

  # Run `code` as a script of its own and wait for the traceback it raises.
  defp traceback_of(code) do
    script = Scripting.run(code, call: false)
    Runner.run(script, code, "<test>", step: {__MODULE__, :self_send, [self()]})
    assert_receive {:error, %Traceback{} = traceback}, 2000

    traceback
  end

  # The path a traceback shows: relative to the game directory, with the
  # platform's separators.
  defp shown(path), do: path |> Paths.relative() |> Paths.display()

  describe "methods applied from a worldlet" do
    test "each frame names the worldlet and the line in it", %{tmp_dir: dir} do
      path =
        write(dir, "animals.txt", """
        !animal!

        def greet(self):
            # Comments and blank lines count, like in the file.

            self.last_call = self.absent_name
        !dog!
        parent = "animal"

        def bark(self):
            self.greet()
        """)

      assert {:ok, _, _} = Pythelix.World.apply(path)

      traceback = traceback_of("!dog!.bark()")
      text = Traceback.format(traceback)

      assert traceback.exception == AttributeError
      assert text =~ "<test>, line 1\n    !dog!.bark()"
      assert text =~ "!dog!.bark, defined in #{shown(path)}, line 11\n    self.greet()"

      # `greet` is inherited: the frame names the entity that defines it.
      assert text =~
               "!animal!.greet, defined in #{shown(path)}, line 6\n    self.last_call = self.absent_name"

      # The method itself remembers where it comes from, with forward slashes
      # whatever the platform, so it can be stored and compared.
      method = Record.get_method(Record.get_entity("animal"), "greet")
      assert method.file == Paths.relative(path)
      refute method.file =~ "\\"
      assert method.line == 4
    end

    test "a worldlet under the game directory is shown relative to it", %{tmp_dir: dir} do
      path = write(dir, "a.txt", "!thing!\ndef run(self):\n    return nothing\n")
      assert {:ok, _, _} = Pythelix.World.apply(path)

      text = traceback_of("!thing!.run()") |> Traceback.format()

      refute text =~ Paths.normalize(File.cwd!())
      assert text =~ "!thing!.run, defined in #{shown(path)}, line 3"
    end
  end

  describe "methods that come from nowhere in particular" do
    test "a method set from code only has its own line" do
      {:ok, _} = Record.create_entity(key: "ent")
      Record.set_method("ent", "fail", :free, "x = 1\nreturn missing")

      text = traceback_of("!ent!.fail()") |> Traceback.format()

      assert text =~ "!ent!.fail, line 2\n    return missing"
      refute text =~ "defined in"
    end

    test "an entity without a key is named by its ID" do
      {:ok, entity} = Record.create_entity()
      Record.set_method(entity.id, "fail", :free, "return missing")

      Runner.run_method({entity, "fail"}, [], %{"self" => entity},
        step: {__MODULE__, :self_send, [self()]}
      )

      assert_receive {:error, %Traceback{} = traceback}, 2000
      text = Traceback.format(traceback)

      assert text =~ "##{entity.id}.fail, line 1
    return missing"
    end
  end

  describe "Method.label/2" do
    test "prefers the key and falls back to the ID" do
      assert Method.label(%Pythelix.Entity{id: 3, key: "room/start", location_id: nil}, "look") ==
               "!room/start!.look"

      assert Method.label(%Pythelix.Entity{id: 3, key: nil, location_id: nil}, "look") ==
               "#3.look"

      assert Method.label("room/start", "look") == "!room/start!.look"
      assert Method.label(3, "look") == "#3.look"
    end
  end
end
