defmodule SproutErp.Repo.Migrations.AddFeesEstimatedToUnits do
  use Ecto.Migration

  # Every fee recorded so far is Sprout's own estimate (8% referral + FBA by
  # category), not an amount reported by Amazon — hence the default.
  def change do
    alter table(:units) do
      add :fees_estimated, :boolean, default: true, null: false
    end
  end
end
