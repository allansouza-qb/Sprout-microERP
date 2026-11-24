<script setup>
import {computed, ref, watch} from "vue"
import {useRoute, useRouter} from "vue-router"

import {api} from "../api"
import Card from "../components/Card.vue"
import EmptyState from "../components/EmptyState.vue"
import GradeBadge from "../components/GradeBadge.vue"
import Icon from "../components/Icon.vue"
import Kpi from "../components/Kpi.vue"
import PageHeader from "../components/PageHeader.vue"
import ProductCell from "../components/ProductCell.vue"
import SaleStatus from "../components/SaleStatus.vue"
import {money, moneyShort, pct, shortDate} from "../format"
import {useLiveData} from "../realtime"

const ranges = [
  {key: "30", label: "30 days"},
  {key: "90", label: "90 days"},
  {key: "all", label: "All time"},
]

const route = useRoute()
const router = useRouter()

const range = computed(() => (ranges.some((r) => r.key === route.query.range) ? route.query.range : "30"))

const data = ref(null)
const {reload} = useLiveData(async () => (data.value = (await api.get("/sales", {range: range.value})).data))
watch(range, reload)

// Fees are Sprout's estimate until the actual Amazon charge is recorded.
const feesLabel = computed(() => (data.value.totals.fees_estimated ? "Estimated fees" : "Amazon fees"))
const margin = (unit) => (unit.sale_price_cents ? unit.profit_cents / unit.sale_price_cents : null)
</script>

<template>
  <template v-if="data">
    <PageHeader title="Sales">
      <template #subtitle>Amazon orders with fully-loaded unit economics.</template>
      <template #actions>
        <a id="export-csv" :href="`/export/sales.csv?range=${range}`" class="btn-sprout btn-sprout-ghost">
          <Icon name="hero-arrow-down-tray" class="size-4" /> Export CSV
        </a>
        <div class="flex rounded-xl border border-line bg-white p-1">
          <RouterLink
            v-for="option in ranges"
            :key="option.key"
            :to="{path: '/sales', query: {range: option.key}}"
            replace
            :class="['rounded-lg px-3 py-1.5 text-[12.5px]', range === option.key ? 'bg-brand-700 text-white' : 'text-ink-2 hover:bg-canvas']"
          >
            {{ option.label }}
          </RouterLink>
        </div>
      </template>
    </PageHeader>

    <div class="mb-6 grid grid-cols-2 gap-6 xl:grid-cols-4">
      <Kpi label="Revenue" :value="moneyShort(data.totals.revenue_cents)" :hint="`${data.totals.orders} orders`" />
      <Kpi :label="feesLabel" :value="moneyShort(data.totals.fees_cents)" :hint="`${pct(data.totals.fees_share)} of revenue`" />
      <Kpi label="Cost of goods" :value="moneyShort(data.totals.cost_cents)" hint="acquisition + refurbishment" />
      <Kpi
        id="kpi-gross-profit"
        label="Gross profit (est.)"
        :value="moneyShort(data.totals.profit_cents)"
        :hint="`${pct(data.totals.margin)} margin`"
      />
    </div>

    <Card :padded="false">
      <div class="overflow-x-auto">
        <table class="table-sprout table-compact">
          <thead>
            <tr>
              <th>Date</th>
              <th class="max-[1439px]:hidden">Amazon order</th>
              <th>Product</th>
              <th>Grade</th>
              <th class="r">Sale</th>
              <th id="fees-header" class="r">{{ feesLabel }}</th>
              <th class="r">Cost</th>
              <th id="profit-header" class="r">Profit (est.)</th>
              <th id="margin-header" class="r">Margin (est.)</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="unit in data.sales"
              :id="`sale-${unit.id}`"
              :key="unit.id"
              class="clickable"
              @click="router.push(`/inventory/${unit.id}`)"
            >
              <td class="whitespace-nowrap text-ink-2">{{ shortDate(unit.sold_on) }}</td>
              <td class="font-mono text-[11.5px] text-ink-2 max-[1439px]:hidden">{{ unit.order_ref }}</td>
              <td class="max-w-[280px]"><ProductCell :product="unit.product" :sub="unit.sku" /></td>
              <td><GradeBadge :grade="unit.grade" /></td>
              <td class="r num font-medium">{{ money(unit.sale_price_cents) }}</td>
              <td class="r num text-ink-2">{{ money(unit.fees_cents) }}</td>
              <td class="r num text-ink-2">{{ money(unit.total_cost_cents) }}</td>
              <td :class="['r num', unit.profit_cents < 0 && 'text-[#b42318]']">{{ money(unit.profit_cents) }}</td>
              <td class="r num text-ink-2">{{ pct(margin(unit)) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!data.sales.length" icon="hero-banknotes" title="No sales in this period" />
      </div>
    </Card>

    <Card id="closed-sales" title="Cancelled & returned" class="mt-6" :padded="false">
      <template #aside>Kept in the sales ledger · not counted as revenue</template>
      <div class="overflow-x-auto">
        <table class="table-sprout">
          <thead>
            <tr>
              <th>Sold</th>
              <th>Amazon order</th>
              <th>Product</th>
              <th>Status</th>
              <th>Closed</th>
              <th>Reason</th>
              <th class="r">Sale</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="sale in data.closed"
              :id="`closed-${sale.id}`"
              :key="sale.id"
              class="clickable"
              @click="router.push(`/inventory/${sale.unit_id}`)"
            >
              <td class="whitespace-nowrap text-ink-2">{{ shortDate(sale.sold_on) }}</td>
              <td class="font-mono text-[11.5px] text-ink-2">{{ sale.order_ref }}</td>
              <td class="max-w-[260px]"><ProductCell :product="sale.unit.product" :sub="sale.unit.sku" /></td>
              <td><SaleStatus :status="sale.status" :label="sale.status_label" /></td>
              <td class="whitespace-nowrap text-ink-2">{{ shortDate(sale.closed_on) }}</td>
              <td class="text-ink-2">{{ sale.close_reason || "—" }}</td>
              <td class="r num">{{ money(sale.price_cents) }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!data.closed.length" icon="hero-arrow-uturn-left" title="No cancellations or returns in this period" />
      </div>
    </Card>
  </template>
</template>
