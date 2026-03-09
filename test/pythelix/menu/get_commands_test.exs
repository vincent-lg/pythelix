defmodule Pythelix.Menu.GetCommandsTest do
  use Pythelix.DataCase, async: false

  @moduletag capture_log: true
  @moduletag :slow

  alias Pythelix.Command.Signature
  alias Pythelix.Game.Hub
  alias Pythelix.Record
  alias Pythelix.Scripting.Namespace.Extended.Menu, as: ExtendedMenu
  alias Pythelix.Scripting.Object.Dict
  alias Pythelix.Scripting.Store

  setup_all do
    case GenServer.start_link(Hub, [], name: Hub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  setup do
    Store.init()
    Record.Cache.clear()

    # Create test generic/client entity with test namespace
    case Record.get_entity("generic/client") do
      nil ->
        {:ok, _} = Record.create_entity(key: "generic/client", virtual: true)

      _ ->
        :ok
    end

    generic_client = Record.get_entity("generic/client")

    Record.set_attribute(
      "generic/client",
      "msg",
      {:extended, Pythelix.Test.TestClientNamespace, :m_msg}
    )

    # Create a test client entity
    {:ok, client} =
      Record.create_entity(key: "test_client", virtual: true, parent: generic_client)

    Record.set_attribute("test_client", "client_id", 999)
    Record.set_attribute("test_client", "pid", self())

    # Create a test menu entity
    {:ok, menu} = Record.create_entity(key: "menu/test", virtual: true)

    Record.set_attribute(
      "menu/test",
      "get_commands",
      {:extended, ExtendedMenu, :m_get_commands}
    )

    client = Record.get_entity("test_client")
    menu = Record.get_entity("menu/test")

    {:ok, client: client, menu: menu}
  end

  describe "get_commands" do
    test "returns all commands when none have can_run", %{client: client, menu: menu} do
      {:ok, _} = Record.create_entity(key: "command/help", virtual: true)
      {:ok, _} = Record.create_entity(key: "command/look", virtual: true)

      Record.set_attribute("menu/test", "commands", %{
        "help" => "command/help",
        "look" => "command/look"
      })

      script_id = Store.new_script()
      script = %Pythelix.Scripting.Interpreter.Script{id: script_id, bytecode: []}
      self_ref = Store.new_reference(menu, script_id)
      entity_ref = Store.new_reference(client, script_id)

      {_script, result} =
        ExtendedMenu.m_get_commands(script, self_ref, [entity_ref], Dict.new())

      assert is_list(result)
      keys = Enum.map(result, & &1.key)
      assert "command/help" in keys
      assert "command/look" in keys
    end

    test "filters out commands where can_run returns False", %{client: client, menu: menu} do
      {:ok, _} = Record.create_entity(key: "command/allowed", virtual: true)
      {_, cr_args} = Signature.constraints("can_run(entity)")
      Record.set_method("command/allowed", "can_run", cr_args, "return True")

      {:ok, _} = Record.create_entity(key: "command/denied", virtual: true)
      Record.set_method("command/denied", "can_run", cr_args, "return False")

      Record.set_attribute("menu/test", "commands", %{
        "allowed" => "command/allowed",
        "denied" => "command/denied"
      })

      script_id = Store.new_script()
      script = %Pythelix.Scripting.Interpreter.Script{id: script_id, bytecode: []}
      self_ref = Store.new_reference(menu, script_id)
      entity_ref = Store.new_reference(client, script_id)

      {_script, result} =
        ExtendedMenu.m_get_commands(script, self_ref, [entity_ref], Dict.new())

      assert is_list(result)
      keys = Enum.map(result, & &1.key)
      assert "command/allowed" in keys
      refute "command/denied" in keys
    end

    test "deduplicates commands appearing under multiple prefixes", %{client: client, menu: menu} do
      {:ok, _} = Record.create_entity(key: "command/help", virtual: true)

      # "help" and "h" and "he" all point to the same command
      Record.set_attribute("menu/test", "commands", %{
        "h" => "command/help",
        "he" => "command/help",
        "help" => "command/help"
      })

      script_id = Store.new_script()
      script = %Pythelix.Scripting.Interpreter.Script{id: script_id, bytecode: []}
      self_ref = Store.new_reference(menu, script_id)
      entity_ref = Store.new_reference(client, script_id)

      {_script, result} =
        ExtendedMenu.m_get_commands(script, self_ref, [entity_ref], Dict.new())

      assert is_list(result)
      assert length(result) == 1
      assert hd(result).key == "command/help"
    end

    test "returns empty list when no commands", %{client: client, menu: menu} do
      Record.set_attribute("menu/test", "commands", %{})

      script_id = Store.new_script()
      script = %Pythelix.Scripting.Interpreter.Script{id: script_id, bytecode: []}
      self_ref = Store.new_reference(menu, script_id)
      entity_ref = Store.new_reference(client, script_id)

      {_script, result} =
        ExtendedMenu.m_get_commands(script, self_ref, [entity_ref], Dict.new())

      assert result == []
    end

    test "handles list of command candidates", %{client: client, menu: menu} do
      {:ok, _} = Record.create_entity(key: "command/admin_look", virtual: true)
      {_, cr_args} = Signature.constraints("can_run(entity)")
      Record.set_method("command/admin_look", "can_run", cr_args, "return False")

      {:ok, _} = Record.create_entity(key: "command/look", virtual: true)

      Record.set_attribute("menu/test", "commands", %{
        "look" => ["command/admin_look", "command/look"]
      })

      script_id = Store.new_script()
      script = %Pythelix.Scripting.Interpreter.Script{id: script_id, bytecode: []}
      self_ref = Store.new_reference(menu, script_id)
      entity_ref = Store.new_reference(client, script_id)

      {_script, result} =
        ExtendedMenu.m_get_commands(script, self_ref, [entity_ref], Dict.new())

      assert is_list(result)
      keys = Enum.map(result, & &1.key)
      # admin_look denied, look allowed (no can_run)
      refute "command/admin_look" in keys
      assert "command/look" in keys
    end
  end
end
