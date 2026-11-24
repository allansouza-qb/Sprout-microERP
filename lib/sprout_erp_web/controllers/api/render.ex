defmodule SproutErpWeb.API.Render do
  @moduledoc """
  Turns domain structs into the JSON the SPA consumes.

  Money stays in integer cents and dates in ISO 8601; every derived number
  (costs, estimated fees, profit, margins, suggested price) is computed here
  from the contexts, so the front end never re-implements a business rule.
  """

  alias SproutErp.{Clock, Inventory, Purchasing}
  alias SproutErp.Catalog.Product
  alias SproutErp.Inventory.{Event, Sale, Unit, WorkItem}
  alias SproutErp.Purchasing.{Lot, Supplier}

  ## Units

  @doc "A unit as shown in lists and boards. Expects `product` preloaded."
  def unit(%Unit{} = u) do
    %{
      id: u.id,
      sku: u.sku,
      serial: u.serial,
      status: u.status,
      grade: u.grade,
      bin: u.bin,
      order_ref: u.order_ref,
      lock_version: u.lock_version,
      received_on: u.received_on,
      listed_on: u.listed_on,
      sold_on: u.sold_on,
      days_in_stock: Unit.days_in_stock(u),
      days_listed:
        if(u.status == "listed" and u.listed_on, do: Date.diff(Clock.today(), u.listed_on)),
      acquisition_cost_cents: u.acquisition_cost_cents,
      refurb_cost_cents: u.refurb_cost_cents,
      total_cost_cents: Unit.total_cost_cents(u),
      list_price_cents: u.list_price_cents,
      sale_price_cents: u.sale_price_cents,
      fees_cents: u.fees_cents,
      fees_estimated: u.fees_estimated,
      estimated_fees_cents:
        u.list_price_cents && Unit.estimated_fees_cents(u, u.list_price_cents),
      profit_cents: Unit.profit_cents(u),
      suggested_price_cents: u.grade && Inventory.suggested_price_cents(u),
      product: product(u.product),
      lot: lot_ref(u.lot),
      bench: bench(u.work_items)
    }
  end

  @doc "Everything the unit screen shows. Expects the preloads of `Inventory.get_unit!/1`."
  def unit_detail(%Unit{} = u) do
    price = u.sale_price_cents || u.list_price_cents
    fees = u.fees_cents || (price && Unit.estimated_fees_cents(u, price))
    profit = Unit.profit_cents(u)

    u
    |> unit()
    |> Map.merge(%{
      economics: %{
        price_cents: price,
        fees_cents: fees,
        profit_cents: profit,
        margin: ratio(profit, price)
      },
      work_items: Enum.map(u.work_items, &work_item/1),
      events: Enum.map(u.events, &event/1),
      sales: Enum.map(u.sales, &sale/1)
    })
  end

  defp bench(work_items) when is_list(work_items) do
    costs = Inventory.bench_costs(work_items)
    done = Enum.count(work_items, & &1.done)

    %{
      completed_cents: costs.completed,
      pending_cents: costs.pending,
      done: done,
      total: length(work_items),
      open: length(work_items) - done
    }
  end

  defp bench(_not_loaded), do: nil

  def work_item(%WorkItem{} = w) do
    %{
      id: w.id,
      description: w.description,
      technician: w.technician,
      parts_cents: w.parts_cents,
      labor_minutes: w.labor_minutes,
      done: w.done,
      cost_cents: WorkItem.cost_cents(w)
    }
  end

  def product(%Product{} = p) do
    %{
      id: p.id,
      name: p.name,
      brand: p.brand,
      category: p.category,
      asin: p.asin,
      msrp_cents: p.msrp_cents,
      icon: Product.category_icon(p.category)
    }
  end

  defp lot_ref(%Lot{} = l) do
    %{id: l.id, reference: l.reference, supplier: supplier_name(l.supplier)}
  end

  defp lot_ref(_not_loaded), do: nil

  defp supplier_name(%Supplier{name: name}), do: name
  defp supplier_name(_not_loaded), do: nil

  ## History and sales ledger

  @doc "A history entry. Includes the unit when it is preloaded (dashboard feed)."
  def event(%Event{} = e) do
    %{
      id: e.id,
      kind: e.kind,
      message: e.message,
      occurred_at: e.occurred_at,
      unit:
        loaded(e.unit) &&
          %{
            id: e.unit.id,
            sku: e.unit.sku,
            name: "#{e.unit.product.brand} #{e.unit.product.name}"
          }
    }
  end

  @doc "A ledger row. Includes the unit when it is preloaded (sales screen)."
  def sale(%Sale{} = s) do
    %{
      id: s.id,
      unit_id: s.unit_id,
      order_ref: s.order_ref,
      status: s.status,
      status_label: Sale.status_label(s.status),
      price_cents: s.price_cents,
      fees_cents: s.fees_cents,
      fees_estimated: s.fees_estimated,
      sold_on: s.sold_on,
      closed_on: s.closed_on,
      close_reason: s.close_reason,
      unit: loaded(s.unit) && %{sku: s.unit.sku, product: product(s.unit.product)}
    }
  end

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(value), do: value

  ## Purchasing

  def supplier(%Supplier{} = s) do
    %{
      id: s.id,
      name: s.name,
      kind: s.kind,
      kind_label: Supplier.kind_label(s.kind),
      location: s.location
    }
  end

  @doc "A lot with its economics (`Purchasing.lot_stats/1`). Expects `supplier` and `units` preloaded."
  def lot(%Lot{} = l) do
    %{
      id: l.id,
      reference: l.reference,
      purchased_on: l.purchased_on,
      total_cost_cents: l.total_cost_cents,
      notes: l.notes,
      supplier: supplier(l.supplier),
      stats: Purchasing.lot_stats(l)
    }
  end

  def supplier_stats(%{supplier: %Supplier{} = s} = stats) do
    stats |> Map.delete(:supplier) |> Map.merge(supplier(s))
  end

  ## Helpers

  def ratio(nil, _base), do: nil
  def ratio(_value, nil), do: nil
  def ratio(_value, 0), do: nil
  def ratio(value, base), do: value / base
end
