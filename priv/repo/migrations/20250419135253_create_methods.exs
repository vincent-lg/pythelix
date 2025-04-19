defmodule Pythelix.Repo.Migrations.CreateMethods do
  use Ecto.Migration

  def change do
    create table(:methods) do
      add :name, :text
      add :value, :text
      add :entity_id, references(:entities, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:methods, [:entity_id])
    create unique_index(:methods, [:entity_id, :name], name: :unique_entity_method)
  end
end
