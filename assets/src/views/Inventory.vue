<script setup>
import {computed, ref, watch} from "vue"
import {useRoute, useRouter} from "vue-router"

import {api} from "../api"
import {boot, statuses} from "../boot"
import Card from "../components/Card.vue"
import EmptyState from "../components/EmptyState.vue"
import GradeBadge from "../components/GradeBadge.vue"
import Icon from "../components/Icon.vue"
import PageHeader from "../components/PageHeader.vue"
import ProductCell from "../components/ProductCell.vue"
import StatusBadge from "../components/StatusBadge.vue"
import {money} from "../format"
import {useLiveData} from "../realtime"

const route = useRoute()
const router = useRouter()

// Filters live in the URL, so a filtered list can be shared and exported as is.
const filters = computed(() => ({
  status: String(route.query.status || ""),
  category: String(route.query.category || ""),
  q: String(route.query.q || ""),
}))

const clean = (params) => Object.fromEntries(Object.entries(params).filter(([, value]) => value))
const setFilters = (changes) => router.replace({path: "/inventory", query: clean({...filters.value, ...changes})})

const data = ref(null)
const {reload} = useLiveData(async () => (data.value = (await api.get("/units", filters.value)).data))
watch(filters, reload)

const tabs = computed(() => [{key: "", label: "All"}, ...statuses])
const total = computed(() => Object.values(data.value.counts).reduce((sum, n) => sum + n, 0))
const count = (status) => (status ? data.value.counts[status] || 0 : total.value)
const exportUrl = computed(() => {
  const query = new URLSearchParams(clean(filters.value)).toString()
  return "/export/inventory.csv" + (query && `?${query}`)
})

// The search box updates the URL shortly after typing stops.
const search = ref(filters.value.q)
let typing = null
watch(search, (text) => {
  clearTimeout(typing)
  typing = setTimeout(() => setFilters({q: text.trim()}), 250)
})
watch(() => filters.value.q, (q) => q !== search.value.trim() && (search.value = q))

const profitClass = (unit) =>
  unit.profit_cents === null ? "text-ink-3" : unit.profit_cents < 0 ? "text-[#b42318]" : "text-ink"
</script>

<template>
  <template v-if="data">
    <PageHeader title="Inventory">
      <template #subtitle>Every physical unit Sprout owns — from the receiving dock to the customer's door.</template>
      <template #actions>
        <a id="export-csv" :href="exportUrl" class="btn-sprout btn-sprout-ghost">
          <Icon name="hero-arrow-down-tray" class="size-4" /> Export CSV
        </a>
        <RouterLink to="/purchasing/new" class="btn-sprout btn-sprout-primary">
          <Icon name="hero-plus" class="size-4" /> Receive lot
        </RouterLink>
      </template>
    </PageHeader>

    <div class="mb-6 flex flex-col gap-3 2xl:flex-row 2xl:items-center 2xl:justify-between">
      <div class="flex w-fit max-w-full gap-1 overflow-x-auto rounded-xl border border-line bg-white p-1">
        <RouterLink
          v-for="tab in tabs"
          :key="tab.key"
          :to="{path: '/inventory', query: clean({...filters, status: tab.key})}"
          replace
          :class="[
            'rounded-lg px-3 py-1.5 text-[12.5px] whitespace-nowrap transition-colors',
            filters.status === tab.key ? 'bg-brand-700 text-white shadow-sm' : 'text-ink-2 hover:bg-canvas hover:text-ink',
          ]"
        >
          {{ tab.label }}
          <span :class="['ml-1 num', filters.status === tab.key ? 'text-white/70' : 'text-ink-3']">{{ count(tab.key) }}</span>
        </RouterLink>
      </div>
      <form id="inventory-filters" class="flex gap-2" @submit.prevent>
        <div class="relative">
          <Icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute z-10 left-3 top-1/2 size-4 -translate-y-1/2 text-ink-3"
          />
          <input v-model="search" type="search" name="q" placeholder="Search SKU, product, serial…" class="input h-9 w-64 pl-9" />
        </div>
        <select
          name="category"
          class="select h-9 w-44"
          :value="filters.category"
          @change="setFilters({category: $event.target.value})"
        >
          <option value="">All categories</option>
          <option v-for="category in boot.categories" :key="category" :value="category">{{ category }}</option>
        </select>
      </form>
    </div>

    <Card :padded="false">
      <div class="overflow-x-auto">
        <table class="table-sprout table-compact">
          <thead>
            <tr>
              <th>Product</th>
              <th>Grade</th>
              <th>Status</th>
              <th class="r">Cost basis</th>
              <th class="r">Price</th>
              <th id="profit-header" class="r">Profit (est.)</th>
              <th class="r">Age</th>
              <th>Lot</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="unit in data.units" :key="unit.id" class="clickable" @click="router.push(`/inventory/${unit.id}`)">
              <td class="max-w-[280px]">
                <ProductCell :product="unit.product" :sub="`${unit.sku} · ${unit.product.category}`" />
              </td>
              <td><GradeBadge :grade="unit.grade" /></td>
              <td><StatusBadge :status="unit.status" /></td>
              <td class="r num">{{ money(unit.total_cost_cents) }}</td>
              <td class="r num">{{ money(unit.sale_price_cents ?? unit.list_price_cents) }}</td>
              <td :class="['r num', profitClass(unit)]">
                {{ money(unit.profit_cents) }}
                <div v-if="unit.status === 'listed'" class="text-[10.5px] text-ink-3">projected</div>
              </td>
              <td class="r num text-ink-2">{{ unit.days_in_stock }}d</td>
              <td class="text-xs text-ink-2 whitespace-nowrap">{{ unit.lot.reference }}</td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!data.units.length" icon="hero-magnifying-glass" title="No units match these filters">
          Try a different status or clear your search.
        </EmptyState>
      </div>
      <template #footer>{{ data.units.length }} units</template>
    </Card>
  </template>
</template>
