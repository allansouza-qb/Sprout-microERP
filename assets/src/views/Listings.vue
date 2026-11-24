<script setup>
import {ref} from "vue"

import {useUnitActions} from "../actions"
import {api} from "../api"
import Card from "../components/Card.vue"
import EmptyState from "../components/EmptyState.vue"
import GradeBadge from "../components/GradeBadge.vue"
import Kpi from "../components/Kpi.vue"
import PageHeader from "../components/PageHeader.vue"
import ProductCell from "../components/ProductCell.vue"
import {decimal, money, moneyShort} from "../format"
import {useLiveData} from "../realtime"

const data = ref(null)
const {reload} = useLiveData(async () => (data.value = (await api.get("/listings")).data))
const {act} = useUnitActions(() => reload())
</script>

<template>
  <template v-if="data">
    <PageHeader title="Amazon listings">
      <template #subtitle>Active Amazon Renewed offers, oldest first. Fees are estimated (8% referral + FBA).</template>
    </PageHeader>

    <div class="mb-6 grid grid-cols-2 gap-6 xl:grid-cols-4">
      <Kpi label="Active listings" :value="String(data.summary.count)" hint="units live" />
      <Kpi label="Listed value" :value="moneyShort(data.summary.value_cents)" hint="at current prices" />
      <Kpi
        label="Projected profit (est.)"
        :value="moneyShort(data.summary.projected_profit_cents)"
        hint="after estimated fees & costs"
      />
      <Kpi label="Avg. days live" :value="decimal(data.summary.avg_days)" hint="since listing" />
    </div>

    <Card :padded="false">
      <div class="overflow-x-auto">
        <table class="table-sprout table-compact">
          <thead>
            <tr>
              <th>Product</th>
              <th class="max-[1439px]:hidden">ASIN</th>
              <th>Grade</th>
              <th class="r">Price</th>
              <th id="fees-header" class="r">Estimated fees</th>
              <th class="r max-[1439px]:hidden">Cost basis</th>
              <th class="r">Proj. profit (est.)</th>
              <th class="r">Live</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="unit in data.units" :key="unit.id" class="group">
              <td class="max-w-[300px]">
                <RouterLink :to="`/inventory/${unit.id}`" class="block hover:opacity-80">
                  <ProductCell :product="unit.product" :sub="unit.sku" />
                </RouterLink>
              </td>
              <td class="font-mono text-[11.5px] text-ink-2 max-[1439px]:hidden">{{ unit.product.asin }}</td>
              <td><GradeBadge :grade="unit.grade" /></td>
              <td class="r num font-medium">{{ money(unit.list_price_cents) }}</td>
              <td class="r num text-ink-2">{{ money(unit.estimated_fees_cents) }}</td>
              <td class="r num text-ink-2 max-[1439px]:hidden">{{ money(unit.total_cost_cents) }}</td>
              <td class="r num">{{ money(unit.profit_cents) }}</td>
              <td class="r">
                <span
                  :class="['num', unit.days_listed > 21 ? 'rounded-full bg-sand-100 px-2 py-0.5 text-[#8a6a36]' : 'text-ink-2']"
                >
                  {{ unit.days_listed }}d
                </span>
              </td>
              <td class="r">
                <button
                  :id="`sell-${unit.id}`"
                  type="button"
                  class="btn-sprout btn-sprout-text btn-sprout-sm row-action"
                  @click="act(unit, 'sell', {}, `${unit.sku} · `)"
                >
                  Record sale
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <EmptyState v-if="!data.units.length" icon="hero-shopping-bag" title="No active listings">
          Units appear here once they are listed from the workshop.
        </EmptyState>
      </div>
    </Card>
  </template>
</template>
