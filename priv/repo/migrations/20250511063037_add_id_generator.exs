defmodule Pythelix.Repo.Migrations.AddIdGenerator do
  use Ecto.Migration

  def change do
    create table(:id_generators) do
      add :type, :text
      add :current_id, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:id_generators, [:type])
  end
end
