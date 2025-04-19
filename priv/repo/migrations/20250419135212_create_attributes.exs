defmodule Pythelix.Repo.Migrations.CreateAttributes do
  use Ecto.Migration

  def change do
    create table(:attributes) do
      add :name, :text
      add :value, :binary
      add :entity_id, references(:entities, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:attributes, [:entity_id])
    create unique_index(:attributes, [:entity_id, :name], name: :unique_entity_attribute)
  end
end
