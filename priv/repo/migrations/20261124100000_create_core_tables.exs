defmodule SproutErp.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    create table(:suppliers) do
      add :name, :string, null: false
      add :kind, :string, null: false
      add :location, :string
      add :email, :string
      add :rating, :float, default: 4.0
      timestamps(type: :utc_datetime)
    end

    create table(:products) do
      add :name, :string, null: false
      add :brand, :string, null: false
      add :category, :string, null: false
      add :asin, :string
      add :msrp_cents, :integer, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:lots) do
      add :reference, :string, null: false
      add :supplier_id, references(:suppliers, on_delete: :restrict), null: false
      add :purchased_on, :date, null: false
      add :total_cost_cents, :integer, null: false, default: 0
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create unique_index(:lots, [:reference])

    create table(:units) do
      add :sku, :string, null: false
      add :product_id, references(:products, on_delete: :restrict), null: false
      add :lot_id, references(:lots, on_delete: :delete_all), null: false
      add :serial, :string
      add :status, :string, null: false, default: "received"
      add :grade, :string
      add :acquisition_cost_cents, :integer, null: false, default: 0
      add :refurb_cost_cents, :integer, null: false, default: 0
      add :list_price_cents, :integer
      add :sale_price_cents, :integer
      add :fees_cents, :integer
      add :bin, :string
      add :order_ref, :string
      add :received_on, :date
      add :listed_on, :date
      add :sold_on, :date
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create unique_index(:units, [:sku])
    create index(:units, [:status])
    create index(:units, [:lot_id])

    create table(:work_items) do
      add :unit_id, references(:units, on_delete: :delete_all), null: false
      add :description, :string, null: false
      add :technician, :string
      add :parts_cents, :integer, null: false, default: 0
      add :labor_minutes, :integer, null: false, default: 0
      add :done, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create index(:work_items, [:unit_id])

    create table(:events) do
      add :unit_id, references(:units, on_delete: :delete_all)
      add :kind, :string, null: false
      add :message, :string, null: false
      add :occurred_at, :utc_datetime, null: false
    end

    create index(:events, [:occurred_at])
    create index(:events, [:unit_id])
  end
end
