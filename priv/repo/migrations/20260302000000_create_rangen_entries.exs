defmodule Pythelix.Repo.Migrations.CreateRangenEntries do
  use Ecto.Migration

  def change do
    create table(:rangen_entries) do
      add :generator_key, :text, null: false
      add :value, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rangen_entries, [:generator_key, :value])
    create index(:rangen_entries, [:generator_key])
  end
end
