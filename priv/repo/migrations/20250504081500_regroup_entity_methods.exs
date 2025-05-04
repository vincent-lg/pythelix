defmodule Pythelix.Repo.Migrations.RegroupEntityMethods do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :methods, :binary
    end

    drop table(:methods)
  end
end
