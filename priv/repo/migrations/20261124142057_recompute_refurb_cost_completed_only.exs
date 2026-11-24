defmodule SproutErp.Repo.Migrations.RecomputeRefurbCostCompletedOnly do
  use Ecto.Migration

  # A unit's refurbishment cost now counts completed bench tasks only.
  # 75 = labor rate in cents per minute (SproutErp.Inventory.WorkItem), frozen here.
  def up, do: execute(recompute("AND w.done"))

  # previous rule: every task, done or not
  def down, do: execute(recompute(""))

  defp recompute(filter) do
    """
    UPDATE units SET refurb_cost_cents = COALESCE((
      SELECT SUM(w.parts_cents + w.labor_minutes * 75)
      FROM work_items w
      WHERE w.unit_id = units.id #{filter}
    ), 0)
    """
  end
end
