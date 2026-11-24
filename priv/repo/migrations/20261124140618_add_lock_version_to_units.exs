defmodule SproutErp.Repo.Migrations.AddLockVersionToUnits do
  use Ecto.Migration

  def change do
    alter table(:units) do
      add :lock_version, :integer, default: 1, null: false
    end
  end
end
