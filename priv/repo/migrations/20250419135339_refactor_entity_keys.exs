defmodule Pythelix.Repo.Migrations.RefactorEntityKeys do
  use Ecto.Migration

  def change do
    # Remove the key column from the entities table
    alter table(:entities) do
      remove :key
    end

    # Create the keys table
    create table(:keys) do
      add :key, :string, null: false
      add :entity_id, references(:entities, on_delete: :delete_all), null: false
    end

    # Add a unique index on the key column in the keys table
    create unique_index(:keys, [:key])
  end
end
