defmodule SproutErp.Repo.Migrations.CreateSales do
  use Ecto.Migration

  # Sales ledger: one row per Amazon order. Rows are never deleted — a
  # cancellation or return changes the row's status and keeps its numbers.
  def change do
    create table(:sales) do
      add :unit_id, references(:units, on_delete: :restrict), null: false
      add :order_ref, :string, null: false
      add :price_cents, :integer, null: false
      add :fees_cents, :integer, null: false
      add :fees_estimated, :boolean, default: true, null: false
      add :sold_on, :date, null: false
      add :status, :string, null: false, default: "completed"
      add :closed_on, :date
      add :close_reason, :string
      timestamps(type: :utc_datetime)
    end

    create index(:sales, [:unit_id])
    create index(:sales, [:status])
    create index(:sales, [:sold_on])

    # backfill: every unit currently sold becomes a completed sale
    execute(
      """
      INSERT INTO sales (unit_id, order_ref, price_cents, fees_cents, fees_estimated,
                         sold_on, status, inserted_at, updated_at)
      SELECT id, COALESCE(order_ref, 'n/a'), sale_price_cents, COALESCE(fees_cents, 0),
             fees_estimated, sold_on, 'completed', updated_at, updated_at
      FROM units WHERE status = 'sold'
      """,
      ""
    )
  end
end
