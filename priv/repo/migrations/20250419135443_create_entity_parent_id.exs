defmodule Pythelix.Repo.Migrations.CreateEntityParentId do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :parent_id, references(:entities, on_delete: :nilify_all)
    end

    create index(:entities, [:parent_id])
  end
end
