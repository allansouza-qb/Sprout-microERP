<script setup>
import {ref} from "vue"
import {useRouter} from "vue-router"

import {api} from "../api"
import Card from "../components/Card.vue"
import EstNote from "../components/EstNote.vue"
import GradeBadge from "../components/GradeBadge.vue"
import Icon from "../components/Icon.vue"
import Kpi from "../components/Kpi.vue"
import PageHeader from "../components/PageHeader.vue"
import ProductCell from "../components/ProductCell.vue"
import StatusBadge from "../components/StatusBadge.vue"
import {date, money, moneyShort, pct, signedPct} from "../format"
import {useLiveData} from "../realtime"
import {setTitle} from "../router"

const props = defineProps({id: {type: String, required: true}})
const router = useRouter()

const lot = ref(null)
useLiveData(async () => {
  lot.value = (await api.get(`/lots/${props.id}`)).data
  setTitle(lot.value.reference)
})
</script>

<template>
  <template v-if="lot">
    <PageHeader :title="lot.reference">
      <template #crumbs>
        <RouterLink to="/purchasing" class="hover:text-ink">Purchasing</RouterLink>
        <Icon name="hero-chevron-right-micro" class="size-3" />
        <span>{{ lot.reference }}</span>
      </template>
      <template #subtitle>
        {{ lot.supplier.name }} · {{ lot.supplier.kind_label }} · purchased {{ date(lot.purchased_on) }}
        <span v-if="lot.notes" class="block mt-1 text-ink-3 italic">“{{ lot.notes }}”</span>
      </template>
    </PageHeader>

    <div class="mb-6 grid grid-cols-2 gap-6 xl:grid-cols-5">
      <Kpi
        id="kpi-invested"
        label="Invested to date"
        :value="moneyShort(lot.stats.invested)"
        :hint="`lot ${moneyShort(lot.total_cost_cents)} + completed bench ${moneyShort(lot.stats.bench_completed)}`"
      />
      <Kpi
        label="Net revenue (est.)"
        :value="moneyShort(lot.stats.net)"
        :hint="`${lot.stats.sold} of ${lot.stats.units} units sold`"
      />
      <Kpi
        id="kpi-realized-roi"
        label="Realized ROI"
        :value="signedPct(lot.stats.realized_roi)"
        :hint="lot.stats.realized_roi === null ? 'no sales yet' : `profit to date ${moneyShort(lot.stats.realized_profit)}`"
      />
      <Kpi
        id="kpi-projected-roi"
        label="Projected ROI"
        :value="signedPct(lot.stats.projected_roi)"
        :hint="`profit ${moneyShort(lot.stats.projected_profit)} · incl. ${moneyShort(lot.stats.bench_pending)} pending bench`"
      />
      <Kpi label="Sell-through" :value="pct(lot.stats.sell_through)" hint="units sold / received" />
    </div>

    <EstNote id="est-note" class="-mt-1 mb-4" />

    <Card title="Units in this lot" :padded="false">
      <div class="overflow-x-auto mt-2">
        <table class="table-sprout table-compact">
          <thead>
            <tr>
              <th>Product</th>
              <th>Grade</th>
              <th>Status</th>
              <th class="r">Allocated cost</th>
              <th class="r">Bench (completed)</th>
              <th class="r">Price</th>
              <th class="r">Profit (est.)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="unit in lot.units" :key="unit.id" class="clickable" @click="router.push(`/inventory/${unit.id}`)">
              <td class="max-w-[300px]">
                <ProductCell :product="unit.product" :sub="`${unit.sku} · ${unit.product.category}`" />
              </td>
              <td><GradeBadge :grade="unit.grade" /></td>
              <td><StatusBadge :status="unit.status" /></td>
              <td class="r num">{{ money(unit.acquisition_cost_cents) }}</td>
              <td class="r num text-ink-2">{{ money(unit.refurb_cost_cents) }}</td>
              <td class="r num">{{ money(unit.sale_price_cents ?? unit.list_price_cents) }}</td>
              <td class="r num">{{ money(unit.profit_cents) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Card>
  </template>
</template>
