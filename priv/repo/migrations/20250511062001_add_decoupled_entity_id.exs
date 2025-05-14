defmodule Pythelix.Repo.Migrations.AddDecoupledEntityId do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :gen_id, :integer
    end

    create index(:entities, [:gen_id])
  end
end
