defmodule Pythelix.SettingsTest do
  @moduledoc """
  `settings.txt` is edited by hand, often in Notepad, by someone who isn't a
  programmer. Whatever that editor does to the file, the settings in it must
  still be read, and a fresh file must explain itself.
  """

  use ExUnit.Case, async: false

  alias Pythelix.Settings

  @moduletag :tmp_dir

  describe "parse/1" do
    test "reads NAME=value lines" do
      assert Settings.parse("TELNET_PORT=4000\nWORLDLETS_PATH=worldlets\n") == %{
               "TELNET_PORT" => "4000",
               "WORLDLETS_PATH" => "worldlets"
             }
    end

    test "ignores comments, blank lines and lines without an equals sign" do
      text = """
      # The port.

      TELNET_PORT=4000
      this line means nothing
      """

      assert Settings.parse(text) == %{"TELNET_PORT" => "4000"}
    end

    test "tolerates spaces around the equals sign" do
      assert Settings.parse("TELNET_PORT = 4000") == %{"TELNET_PORT" => "4000"}
    end

    test "keeps everything after the first equals sign" do
      assert Settings.parse("SECRET_KEY_BASE=abc==") == %{"SECRET_KEY_BASE" => "abc=="}
    end

    test "survives CRLF line endings and a byte-order mark" do
      assert Settings.parse("﻿TELNET_PORT=4000\r\nWEB_PORT=8000\r\n") == %{
               "TELNET_PORT" => "4000",
               "WEB_PORT" => "8000"
             }
    end

    test "reads a path with an accent saved by a Windows editor" do
      # "données" in CP1252: the é is a single byte, invalid as UTF-8.
      cp1252 = "WORLDLETS_PATH=donn" <> <<233>> <> "es"

      assert Settings.parse(cp1252) == %{"WORLDLETS_PATH" => "données"}
    end
  end

  describe "read/1 and ensure!/2" do
    test "a missing file is :nofile", %{tmp_dir: dir} do
      assert Settings.read(Path.join(dir, "settings.txt")) == :nofile
    end

    test "a fresh file is generated with every setting and its default", %{tmp_dir: dir} do
      path = Settings.path(dir)

      ExUnit.CaptureIO.capture_io(fn ->
        send(self(), {:settings, Settings.ensure!(path)})
      end)

      assert_received {:settings, settings}
      assert File.exists?(path)

      assert settings["WORLDLETS_PATH"] == "worldlets"
      assert settings["TELNET_PORT"] == "4000"
      assert settings["DEFAULT_ENCODING"] == "utf-8"
      assert settings["WORLDLETS_ENCODING"] == ""
      assert settings["GENERIC_CLIENT"] == "generic/client"
      assert String.length(settings["SECRET_KEY_BASE"]) > 40

      # Reading it back gives the same settings: the generated file is the
      # source from now on.
      assert Settings.read(path) == {:ok, settings}
    end

    test "the generated file explains itself", %{tmp_dir: dir} do
      path = Settings.path(dir)
      ExUnit.CaptureIO.capture_io(fn -> Settings.ensure!(path) end)

      text = File.read!(path)

      # Every supported encoding is listed next to the setting that takes it.
      for encoding <- Pythelix.Network.Encoding.supported_encodings() do
        assert text =~ encoding
      end

      assert text =~ "# WORLDLETS_ENCODING is how a worldlet"
    end

    test "a seed carries values over into the generated file", %{tmp_dir: dir} do
      path = Settings.path(dir)

      ExUnit.CaptureIO.capture_io(fn ->
        Settings.ensure!(path, %{"SECRET_KEY_BASE" => "kept", "TELNET_PORT" => "4321"})
      end)

      assert {:ok, settings} = Settings.read(path)
      assert settings["SECRET_KEY_BASE"] == "kept"
      assert settings["TELNET_PORT"] == "4321"
      assert settings["WEB_PORT"] == "8000"
    end

    test "an existing file is read, not overwritten", %{tmp_dir: dir} do
      path = Settings.path(dir)
      File.write!(path, "TELNET_PORT=5000\n")

      assert Settings.ensure!(path) == %{"TELNET_PORT" => "5000"}
      assert File.read!(path) == "TELNET_PORT=5000\n"
    end
  end

  describe "get/3" do
    setup do
      System.delete_env("PYTHELIX_TEST_SETTING")
      System.delete_env("PYTHELIX_TEST_SETTING_OLD")

      on_exit(fn ->
        System.delete_env("PYTHELIX_TEST_SETTING")
        System.delete_env("PYTHELIX_TEST_SETTING_OLD")
      end)
    end

    test "the default when neither the environment nor the file has it" do
      assert Settings.get(%{}, ["PYTHELIX_TEST_SETTING"], "fallback") == "fallback"
    end

    test "the file beats the default" do
      settings = %{"PYTHELIX_TEST_SETTING" => "from file"}

      assert Settings.get(settings, ["PYTHELIX_TEST_SETTING"], "fallback") == "from file"
    end

    test "the environment beats the file" do
      System.put_env("PYTHELIX_TEST_SETTING", "from env")
      settings = %{"PYTHELIX_TEST_SETTING" => "from file"}

      assert Settings.get(settings, ["PYTHELIX_TEST_SETTING"], "fallback") == "from env"
    end

    test "an older environment name still works" do
      System.put_env("PYTHELIX_TEST_SETTING_OLD", "from old env")

      assert Settings.get(%{}, ["PYTHELIX_TEST_SETTING", "PYTHELIX_TEST_SETTING_OLD"], "x") ==
               "from old env"
    end

    test "an empty value means not set" do
      System.put_env("PYTHELIX_TEST_SETTING", "")
      settings = %{"PYTHELIX_TEST_SETTING" => "  "}

      assert Settings.get(settings, ["PYTHELIX_TEST_SETTING"], "fallback") == "fallback"
    end
  end
end
