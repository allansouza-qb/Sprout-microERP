<script setup>
import {computed, ref} from "vue"

import {api} from "../api"
import {boot, statusLabel} from "../boot"
import Card from "../components/Card.vue"
import EmptyState from "../components/EmptyState.vue"
import Icon from "../components/Icon.vue"
import Kpi from "../components/Kpi.vue"
import PageHeader from "../components/PageHeader.vue"
import {eventIcon} from "../events"
import {ago, decimal, money, moneyCompact, moneyShort, pct, shortDate} from "../format"
import {useLiveData} from "../realtime"

const data = ref(null)
useLiveData(async () => (data.value = (await api.get("/dashboard")).data))

// One shade per stage, lightest for the dock and darkest for live listings.
const ramp = {
  received: "var(--ramp-1)",
  inspecting: "var(--ramp-2)",
  refurbishing: "var(--ramp-3)",
  ready: "var(--ramp-4)",
  listed: "var(--ramp-5)",
}

const pipelineTotal = computed(() => data.value.pipeline.reduce((sum, stage) => sum + stage.count, 0))
const maxProfit = computed(() => Math.max(1, ...data.value.categories.map((c) => c.profit)))
const lastWeek = computed(() => data.value.chart.weeks.length - 1)
</script>

<template>
  <template v-if="data">
    <PageHeader :title="`${data.greeting}, Sprout`">
      <template #subtitle>Here's how the refurbishment line and the Amazon storefront are performing.</template>
      <template #actions>
        <RouterLink to="/workshop" class="btn-sprout btn-sprout-ghost">
          <Icon name="hero-wrench-screwdriver" class="size-4" /> Open workshop
        </RouterLink>
        <RouterLink to="/purchasing/new" class="btn-sprout btn-sprout-primary">
          <Icon name="hero-plus" class="size-4" /> Receive lot
        </RouterLink>
      </template>
    </PageHeader>

    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-4">
      <Kpi
        label="Revenue · last 30 days"
        :value="moneyShort(data.kpis.revenue_cents)"
        :delta="data.kpis.revenue_delta"
        hint="vs prior 30 days"
      />
      <Kpi
        id="kpi-gross-profit"
        label="Gross profit (est.) · last 30 days"
        :value="moneyShort(data.kpis.profit_cents)"
        :delta="data.kpis.profit_delta"
        :hint="`${pct(data.kpis.margin)} margin`"
      />
      <Kpi
        label="Units sold · last 30 days"
        :value="String(data.kpis.units_sold)"
        :delta="data.kpis.units_sold_delta"
        hint="vs prior 30 days"
      />
      <Kpi
        label="Avg. days to sell"
        :value="decimal(data.kpis.avg_days_to_sell)"
        :delta="data.kpis.avg_days_to_sell_delta"
        invert
        hint="receipt → Amazon order"
      />
    </div>

    <div class="mt-6 grid grid-cols-1 gap-6 xl:grid-cols-3">
      <Card title="Weekly revenue" class="xl:col-span-2">
        <template #aside>Last 12 weeks · hover a bar for detail</template>
        <div class="flex gap-3">
          <div class="flex h-[19rem] flex-col justify-between pb-6 text-right text-[11px] text-ink-3 num">
            <span v-for="tick in data.chart.ticks" :key="tick" class="-translate-y-1.5 leading-none">
              {{ moneyCompact(tick) }}
            </span>
          </div>
          <div class="relative min-w-0 flex-1">
            <div class="absolute inset-x-0 top-0 bottom-6 flex flex-col justify-between">
              <div v-for="tick in data.chart.ticks" :key="tick" class="border-t border-dashed border-line-soft" />
            </div>
            <div class="relative flex h-[19rem] items-end gap-[6px] sm:gap-2.5">
              <div
                v-for="(week, i) in data.chart.weeks"
                :key="week.start"
                class="bar-col group relative flex h-full min-w-0 flex-1 flex-col items-center justify-end"
              >
                <div class="flex h-[calc(100%-1.5rem)] w-full items-end justify-center">
                  <div
                    :class="['bar w-full max-w-[38px] rounded-t-[4px] transition-colors', i === lastWeek ? '!bg-brand-300' : 'bg-brand-600']"
                    :style="{height: `${Math.max((week.revenue / data.chart.top) * 100, 0.8)}%`}"
                  />
                </div>
                <div
                  :class="['h-6 pt-2 text-[10.5px] text-ink-3 whitespace-nowrap', (lastWeek - i) % 2 === 1 && 'invisible sm:visible']"
                >
                  {{ shortDate(week.start) }}
                </div>
                <div class="tip absolute bottom-[calc(100%-1rem)] left-1/2 z-10 w-44 rounded-lg border border-line bg-white p-3 text-xs shadow-lg">
                  <div class="font-medium text-ink">
                    Week of {{ shortDate(week.start) }}{{ i === lastWeek ? " · to date" : "" }}
                  </div>
                  <div class="mt-2 flex justify-between text-ink-2">
                    <span>Revenue</span><span class="num text-ink">{{ moneyShort(week.revenue) }}</span>
                  </div>
                  <div class="mt-1 flex justify-between text-ink-2">
                    <span>Gross profit (est.)</span><span class="num text-ink">{{ moneyShort(week.profit) }}</span>
                  </div>
                  <div class="mt-1 flex justify-between text-ink-2">
                    <span>Units</span><span class="num text-ink">{{ week.units }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Card>

      <Card title="Pipeline">
        <template #aside>{{ data.inventory_units }} units in stock</template>
        <div class="flex h-3 w-full gap-[2px] overflow-hidden rounded-full">
          <template v-for="stage in data.pipeline" :key="stage.status">
            <div
              v-if="stage.count > 0"
              class="h-full first:rounded-l-full last:rounded-r-full"
              :style="{width: `${(stage.count / Math.max(pipelineTotal, 1)) * 100}%`, background: ramp[stage.status]}"
              :title="`${stage.label}: ${stage.count}`"
            />
          </template>
        </div>
        <ul class="mt-5 space-y-1">
          <li v-for="stage in data.pipeline" :key="stage.status">
            <RouterLink
              :to="{path: '/inventory', query: {status: stage.status}}"
              class="flex items-center gap-3 rounded-lg px-2 py-1.5 -mx-2 hover:bg-canvas"
            >
              <span class="size-2.5 rounded-sm" :style="{background: ramp[stage.status]}" />
              <span class="flex-1 text-[13px] text-ink-2">{{ stage.label }}</span>
              <span class="text-[13px] font-medium text-ink num">{{ stage.count }}</span>
            </RouterLink>
          </li>
        </ul>
        <div class="mt-6 grid grid-cols-2 gap-3 border-t border-line-soft pt-4">
          <div>
            <div class="text-[11.5px] text-ink-3">Inventory at cost</div>
            <div class="mt-1 font-display text-2xl num">{{ moneyShort(data.inventory_cost_cents) }}</div>
          </div>
          <div>
            <div class="text-[11.5px] text-ink-3">Live on Amazon</div>
            <div class="mt-1 font-display text-2xl num">{{ moneyShort(data.listed_value_cents) }}</div>
          </div>
        </div>
      </Card>
    </div>

    <div class="mt-6 grid grid-cols-1 gap-6 xl:grid-cols-3">
      <Card title="Category performance" :padded="false">
        <template #aside>All-time · est. fees</template>
        <div class="divide-y divide-line-soft px-5 pb-2">
          <div v-for="category in data.categories" :key="category.category" class="py-3">
            <div class="flex items-center gap-2.5">
              <Icon :name="category.icon" class="size-4 text-ink-3" />
              <span class="flex-1 text-[13px] font-medium">{{ category.category }}</span>
              <span class="text-[13px] num">{{ moneyShort(category.profit) }}</span>
            </div>
            <div class="mt-2 flex items-center gap-3">
              <div class="h-1.5 flex-1 rounded-full bg-canvas">
                <div
                  class="h-full rounded-full bg-brand-500"
                  :style="{width: `${Math.max((category.profit / maxProfit) * 100, 2)}%`}"
                />
              </div>
              <span class="w-28 text-right text-[11px] text-ink-3 num">
                {{ category.units }} units · {{ pct(category.margin) }}
              </span>
            </div>
          </div>
        </div>
      </Card>

      <Card title="Needs attention" :padded="false">
        <template #aside>Aging stock</template>
        <EmptyState v-if="!data.aging.length" icon="hero-check" title="Nothing is stuck">
          Every unit is moving on schedule.
        </EmptyState>
        <ul class="divide-y divide-line-soft">
          <li v-for="{unit, days} in data.aging" :key="unit.id">
            <RouterLink :to="`/inventory/${unit.id}`" class="flex items-center gap-3 px-5 py-3 hover:bg-canvas/60">
              <div class="grid size-8 shrink-0 place-items-center rounded-full bg-muted text-ink-2">
                <Icon :name="unit.status === 'listed' ? 'hero-tag' : 'hero-wrench'" class="size-4" />
              </div>
              <div class="min-w-0 flex-1">
                <div class="truncate text-[13px] font-medium">{{ unit.product.brand }} {{ unit.product.name }}</div>
                <div class="truncate text-xs text-ink-3">
                  <template v-if="unit.status === 'listed'">
                    Listed {{ days }} days at {{ money(unit.list_price_cents) }} — consider repricing
                  </template>
                  <template v-else>{{ statusLabel(unit.status) }} for {{ days }} days since receipt</template>
                </div>
              </div>
              <Icon name="hero-chevron-right-mini" class="size-4 text-ink-3" />
            </RouterLink>
          </li>
        </ul>
      </Card>

      <Card title="Recent activity" :padded="false">
        <template #aside>
          <span class="inline-flex items-center gap-1.5">
            <span class="size-1.5 rounded-full bg-brand-500 animate-pulse" /> Live
          </span>
        </template>
        <ul class="px-5 pb-3">
          <li v-for="event in data.events" :key="event.id" class="relative flex gap-3 py-2.5">
            <div class="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-muted text-ink-2">
              <Icon :name="eventIcon(event.kind)" class="size-3.5" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-[12.5px] leading-snug text-ink">{{ event.message }}</div>
              <div v-if="event.unit" class="mt-0.5 truncate text-[11.5px] text-ink-3">
                <RouterLink :to="`/inventory/${event.unit.id}`" class="hover:text-ink">
                  {{ event.unit.sku }} · {{ event.unit.name }}
                </RouterLink>
              </div>
            </div>
            <div class="shrink-0 text-right text-[11px] text-ink-3">
              {{ ago(event.occurred_at, boot.time_zone) }}
            </div>
          </li>
        </ul>
      </Card>
    </div>
  </template>
</template>
