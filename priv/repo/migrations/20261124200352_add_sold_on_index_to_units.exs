defmodule SproutErp.Repo.Migrations.AddSoldOnIndexToUnits do
  use Ecto.Migration

  # The dashboard and the sales screen aggregate sold units by sale date.
  def change do
    create index(:units, [:sold_on], where: "status = 'sold'")
  end
end
