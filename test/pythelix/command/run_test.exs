defmodule Pythelix.Command.RunTest do
  use Pythelix.CommandCase

  alias Pythelix.Record

  describe "run without refining" do
    test "a command without argument" do
      {:ok, command} = Record.create_entity(key: "command/test")
      Record.set_attribute(command.key, "name", "test")
      Record.set_method(command.key, "run", :free, """
      client.msg("hello")
      """)
      run_command(command, "")
      assert_receive {:message, "hello"}
    end
  end
end
