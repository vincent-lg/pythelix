defmodule Pythelix.Scripting.Entity.KeyTest do
  @moduledoc """
  Module to test the entity API in its keys.
  """

  use Pythelix.DataCase

  alias Pythelix.Record

  describe "creation" do
    test "no two entities with the same key should be allowed" do
      {:ok, _} = Record.create_entity(key: "test")
      attempt = Record.create_entity(key: "test")
      assert !match?({:ok, _}, attempt)
    end

    test "uncached, no two entities with the same key should be allowed" do
      {:ok, _} = Record.create_entity(key: "test")
      Record.Cache.commit_and_clear()
      attempt = Record.create_entity(key: "test")
      assert !match?({:ok, _}, attempt)
    end
  end
end
