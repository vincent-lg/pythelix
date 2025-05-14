defmodule Pythelix.Repo.Migrations.DropAutoIncrementIdForEntitiesAndAttributes do
  use Ecto.Migration

  def change do
    drop table(:entities)

    create table(:entities, primary_key: false) do
      add :gen_id, :integer, primary_key: true
      add :key, :text
      add :parent_id, references(:entities, column: :gen_id, type: :integer, on_delete: :nilify_all)
      add :location_id, references(:entities, column: :gen_id, type: :integer, on_delete: :nilify_all)
      add :methods, :binary

      timestamps(type: :utc_datetime)
    end

    create index(:entities, [:location_id])
    create index(:entities, [:parent_id])

    # Attributes
    drop table(:attributes)

    create table(:attributes, primary_key: false) do
      add :gen_id, :integer, primary_key: true
      add :name, :text
      add :value, :binary
      add :entity_gen_id, references(:entities, column: :gen_id, type: :integer, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:attributes, [:entity_gen_id])
    create unique_index(:attributes, [:entity_gen_id, :name], name: :unique_entity_attribute)
  end
end
