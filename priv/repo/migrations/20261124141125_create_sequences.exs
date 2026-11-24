defmodule SproutErp.Repo.Migrations.CreateSequences do
  use Ecto.Migration

  def up do
    create table(:sequences, primary_key: false) do
      add :name, :string, primary_key: true
      add :value, :integer, null: false
    end

    # Continue after the highest SKU already issued (SPR-NNNNN); start at 10000
    # on an empty database so the first unit is SPR-10001.
    execute """
    INSERT INTO sequences (name, value)
    SELECT 'unit_sku', COALESCE(MAX(CAST(SUBSTR(sku, 5) AS INTEGER)), 10000) FROM units
    """
  end

  def down do
    drop table(:sequences)
  end
end
