<script setup>
import {ref} from "vue"

import {useUnitActions} from "../actions"
import {api} from "../api"
import {grades, gradeShort} from "../boot"
import Icon from "../components/Icon.vue"
import PageHeader from "../components/PageHeader.vue"
import {money, plural} from "../format"
import {useLiveData} from "../realtime"

const columns = {
  received: {title: "Awaiting inspection", sub: "Fresh from the dock", dot: "bg-ink-3"},
  inspecting: {title: "Inspection", sub: "Diagnostics & grading", dot: "bg-[oklch(0.75_0.15_75)]"},
  refurbishing: {title: "On the bench", sub: "Repairs & cosmetic work", dot: "bg-[oklch(0.75_0.15_75)]"},
  ready: {title: "Ready to list", sub: "Passed QC, on the shelf", dot: "bg-[oklch(0.62_0.15_255)]"},
}

const board = ref(null)
const {reload} = useLiveData(async () => (board.value = (await api.get("/workshop")).data))
const {act} = useUnitActions(() => reload())

// The board refetches after each action, so the card moves to its new column.
const go = (unit, action, body) => act(unit, action, body, `${unit.sku} · `)

const ageClass = (unit) =>
  unit.days_in_stock > 10 ? "font-medium text-[#b42318]" : unit.days_in_stock > 6 ? "text-[#8a5a00]" : "text-ink-3"

const gradeDot = (grade) => ({premium: "bg-sand-500", excellent: "bg-brand-500"})[grade] || "bg-ink-3"
</script>

<template>
  <template v-if="board">
    <PageHeader title="Workshop">
      <template #subtitle>Move units from the receiving dock to the shelf. Oldest units surface first.</template>
    </PageHeader>

    <div class="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-4">
      <section
        v-for="column in board"
        :key="column.status"
        :data-column="column.status"
        class="flex min-h-[420px] flex-col rounded-[0.625rem] border border-line bg-muted p-2.5"
      >
        <header class="flex items-start justify-between px-2 pt-1.5 pb-3">
          <div>
            <div class="flex items-center gap-2 text-[13.5px] font-semibold text-ink">
              <span :class="['size-2 rounded-full', columns[column.status].dot]" />{{ columns[column.status].title }}
            </div>
            <div class="text-[11.5px] text-ink-3">{{ columns[column.status].sub }}</div>
          </div>
          <span class="rounded-full bg-white px-2 py-0.5 text-xs font-medium text-ink-2 num shadow-sm">
            {{ column.units.length }}
          </span>
        </header>

        <div class="flex-1 space-y-2 overflow-y-auto">
          <article
            v-for="unit in column.units"
            :id="`card-${unit.id}`"
            :key="unit.id"
            class="rounded-[0.625rem] border border-line-soft bg-surface p-3 transition-shadow hover:shadow-[0_6px_16px_-8px_oklch(0.16_0.01_260/0.25)]"
          >
            <RouterLink :to="`/inventory/${unit.id}`" class="block">
              <div class="flex items-start justify-between gap-2">
                <div class="text-[13.5px] font-medium leading-snug text-ink">
                  {{ unit.product.brand }} {{ unit.product.name }}
                </div>
                <span :class="['shrink-0 pt-0.5 text-[11px] num', ageClass(unit)]">{{ unit.days_in_stock }}d</span>
              </div>
              <div class="mt-1 text-[11.5px] text-ink-3 num">
                <span class="font-mono">{{ unit.sku }}</span> · {{ money(unit.total_cost_cents) }}
              </div>
            </RouterLink>

            <div v-if="['refurbishing', 'ready'].includes(column.status)" class="mt-2.5 flex items-center gap-2">
              <span class="inline-flex items-center gap-1.5 text-[11.5px] text-ink-2">
                <span :class="['size-1.5 rounded-full', gradeDot(unit.grade)]" />
                {{ gradeShort(unit.grade) }}
              </span>
              <div v-if="column.status === 'refurbishing'" class="flex flex-1 items-center gap-2">
                <div class="h-1 flex-1 rounded-full bg-canvas">
                  <div
                    class="h-full rounded-full bg-brand-500"
                    :style="{width: `${unit.bench.total ? (unit.bench.done / unit.bench.total) * 100 : 0}%`}"
                  />
                </div>
                <span class="text-[11px] text-ink-3 num">{{ unit.bench.done }}/{{ unit.bench.total }}</span>
              </div>
              <span v-else class="ml-auto text-[11.5px] text-ink-2">Bin {{ unit.bin }}</span>
            </div>

            <div class="mt-2.5 border-t border-line-soft pt-2.5">
              <button
                v-if="column.status === 'received'"
                type="button"
                class="btn-sprout btn-sprout-ghost btn-sprout-sm w-full justify-center"
                @click="go(unit, 'start_inspection')"
              >
                <Icon name="hero-magnifying-glass-micro" class="size-3.5" /> Start inspection
              </button>

              <template v-else-if="column.status === 'inspecting'">
                <div class="text-[11px] text-ink-3 mb-1.5">Grade as</div>
                <div class="grid grid-cols-2 gap-1">
                  <button
                    v-for="grade in grades"
                    :key="grade.key"
                    type="button"
                    :title="grade.label"
                    class="cursor-pointer rounded-md border border-line py-1 text-[11px] font-medium text-ink-2 transition hover:border-brand-500 hover:bg-brand-50 hover:text-brand-700"
                    @click="go(unit, 'grade', {grade: grade.key})"
                  >
                    {{ grade.short }}
                  </button>
                </div>
              </template>

              <template v-else-if="column.status === 'refurbishing'">
                <RouterLink
                  v-if="unit.bench.open > 0"
                  :to="`/inventory/${unit.id}`"
                  class="btn-sprout btn-sprout-ghost btn-sprout-sm w-full justify-center"
                >
                  <Icon name="hero-wrench-micro" class="size-3.5" /> {{ plural(unit.bench.open, "open task") }}
                </RouterLink>
                <button
                  v-else
                  type="button"
                  class="btn-sprout btn-sprout-primary btn-sprout-sm w-full justify-center"
                  @click="go(unit, 'mark_ready')"
                >
                  <Icon name="hero-check-badge-micro" class="size-3.5" /> Pass QC
                </button>
              </template>

              <button
                v-else
                type="button"
                class="btn-sprout btn-sprout-primary btn-sprout-sm w-full justify-center"
                @click="go(unit, 'list')"
              >
                <Icon name="hero-shopping-bag-micro" class="size-3.5" /> List at {{ money(unit.suggested_price_cents) }}
              </button>
            </div>
          </article>

          <div
            v-if="!column.units.length"
            class="grid h-32 place-items-center rounded-xl border border-dashed border-line text-xs text-ink-3"
          >
            Nothing here
          </div>
        </div>
      </section>
    </div>
  </template>
</template>
