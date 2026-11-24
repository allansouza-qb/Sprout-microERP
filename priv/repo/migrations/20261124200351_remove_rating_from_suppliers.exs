defmodule SproutErp.Repo.Migrations.RemoveRatingFromSuppliers do
  use Ecto.Migration

  # The supplier cards show sell-through and margin from recorded sales; the
  # hand-typed rating was never read.
  def change do
    alter table(:suppliers) do
      remove :rating, :float, default: 4.0
    end
  end
end
