defmodule Pythelix.Repo.Migrations.RegroupEntityKeys do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :key, :text
    end

    create index(:entities, [:key])
    drop table(:keys)
  end
end
