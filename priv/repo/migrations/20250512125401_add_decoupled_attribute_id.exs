defmodule Pythelix.Repo.Migrations.AddDecoupledAttributeId do
  use Ecto.Migration

  def change do
    alter table(:attributes) do
      add :gen_id, :integer
    end

    create index(:attributes, [:gen_id])
  end
end
