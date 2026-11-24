<script setup>
import {computed, reactive, ref, watch} from "vue"

import {useUnitActions} from "../actions"
import {api} from "../api"
import {boot, gradeLabel, grades} from "../boot"
import Card from "../components/Card.vue"
import EmptyState from "../components/EmptyState.vue"
import GradeBadge from "../components/GradeBadge.vue"
import Icon from "../components/Icon.vue"
import PageHeader from "../components/PageHeader.vue"
import SaleStatus from "../components/SaleStatus.vue"
import StatusBadge from "../components/StatusBadge.vue"
import Stepper from "../components/Stepper.vue"
import {eventIcon} from "../events"
import {date, dateTime, money, pct, plural} from "../format"
import {useLiveData} from "../realtime"
import {setTitle} from "../router"

const props = defineProps({id: {type: String, required: true}})

const unit = ref(null)
const missing = ref(false)

// What the price fields show: the suggested price before listing, the list price after.
const priceText = (cents) => (cents ? money(cents).replace("$", "") : "")
const forms = reactive({list: "", reprice: "", sale: "", reason: ""})
const task = reactive({description: "", technician: boot.technicians?.[0] || "", parts: "", minutes: "20"})

function show(data) {
  // Keep what the user is typing when the same stage is just refreshed.
  const moved = !unit.value || unit.value.status !== data.status || unit.value.list_price_cents !== data.list_price_cents
  unit.value = data
  setTitle(data.sku)

  if (moved) {
    forms.list = priceText(data.suggested_price_cents)
    forms.reprice = priceText(data.list_price_cents)
    forms.sale = priceText(data.list_price_cents)
    forms.reason = ""
  }
}

const {reload} = useLiveData(async () => {
  try {
    show((await api.get(`/units/${props.id}`)).data)
  } catch (error) {
    if (error.status === 404) missing.value = true
    else throw error
  }
})

// Actions answer with the refreshed unit, so no second request is needed.
const {act, run} = useUnitActions((data) => (data ? show(data) : reload()))

const editable = computed(() => ["received", "inspecting", "refurbishing"].includes(unit.value.status))
const grade = computed(() => grades.find((g) => g.key === unit.value.grade))
const estimated = computed(() => !(unit.value.status === "sold" && unit.value.fees_estimated === false))
const est = computed(() => (estimated.value ? " (est.)" : ""))

const benchTitle = computed(() => {
  const {open, total} = unit.value.bench
  if (open > 0) return `On the bench · ${plural(open, "task")} open`
  return total === 0 ? "On the bench · no tasks logged yet" : "Bench work complete"
})

async function addTask() {
  const added = await run(() => api.post(`/units/${unit.value.id}/work_items`, task))
  if (added) Object.assign(task, {description: "", parts: "", minutes: "20"})
}

const toggleTask = (item) => run(() => api.patch(`/work_items/${item.id}/toggle`))
const deleteTask = (item) => run(() => api.delete(`/work_items/${item.id}`))

// A different unit in the same screen (e.g. from a link in the history).
watch(() => props.id, reload)
</script>

<template>
  <EmptyState v-if="missing" icon="hero-archive-box" title="This unit does not exist">
    <RouterLink to="/inventory" class="text-brand-700 hover:underline">Back to inventory</RouterLink>
  </EmptyState>

  <template v-else-if="unit">
    <PageHeader :title="`${unit.product.brand} ${unit.product.name}`">
      <template #crumbs>
        <RouterLink to="/inventory" class="hover:text-ink">Inventory</RouterLink>
        <Icon name="hero-chevron-right-micro" class="size-3" />
        <span class="font-mono">{{ unit.sku }}</span>
      </template>
      <template #subtitle>
        <span class="inline-flex flex-wrap items-center gap-2">
          <StatusBadge :status="unit.status" />
          <GradeBadge v-if="unit.grade" :grade="unit.grade" />
          <span class="text-ink-3">·</span> {{ unit.product.category }} <span class="text-ink-3">·</span> Serial
          <span class="font-mono text-xs">{{ unit.serial }}</span>
        </span>
      </template>
    </PageHeader>

    <!-- Where the unit is and the next step -->
    <Card id="next-step" class="mb-6">
      <Stepper :status="unit.status" />
      <div class="mt-5 border-t border-line-soft pt-5">
        <div v-if="unit.status === 'received'" class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div class="text-[14px] font-semibold text-ink">Waiting for inspection</div>
            <div class="mt-0.5 text-[12.5px] text-ink-2">Unbox, photograph and run diagnostics before grading.</div>
          </div>
          <button type="button" class="btn-sprout btn-sprout-primary" @click="act(unit, 'start_inspection')">
            <Icon name="hero-magnifying-glass" class="size-4" /> Start inspection
          </button>
        </div>

        <template v-else-if="unit.status === 'inspecting'">
          <div class="text-[14px] font-semibold text-ink">Assign an Amazon Renewed grade</div>
          <div class="mt-0.5 text-[12.5px] text-ink-2">The grade sets the target price and the refurbishment scope.</div>
          <div class="mt-6 grid grid-cols-2 gap-2 lg:grid-cols-4">
            <button
              v-for="option in grades"
              :key="option.key"
              type="button"
              :data-grade="option.key"
              class="group cursor-pointer rounded-xl border border-line bg-white p-3.5 text-left transition hover:border-brand-500 hover:shadow-[0_0_0_3px_color-mix(in_oklch,var(--color-brand-500)_14%,transparent)]"
              @click="act(unit, 'grade', {grade: option.key})"
            >
              <div class="flex items-center justify-between">
                <GradeBadge :grade="option.key" />
                <span class="text-[11px] text-ink-3 num">{{ pct(option.factor) }} MSRP</span>
              </div>
              <div class="mt-2 text-xs leading-snug text-ink-2">{{ option.help }}</div>
            </button>
          </div>
        </template>

        <div v-else-if="unit.status === 'refurbishing'" class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div class="text-[14px] font-semibold text-ink">{{ benchTitle }}</div>
            <div class="mt-0.5 text-[12.5px] text-ink-2">
              Close every bench task, then run final QC to move the unit to the shelf.
            </div>
          </div>
          <button type="button" class="btn-sprout btn-sprout-primary" :disabled="unit.bench.open > 0" @click="act(unit, 'mark_ready')">
            <Icon name="hero-check-badge" class="size-4" /> Pass QC
          </button>
        </div>

        <div v-else-if="unit.status === 'ready'" class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <div class="text-[14px] font-semibold text-ink">Ready to list on Amazon Renewed</div>
            <div class="mt-0.5 text-[12.5px] text-ink-2">
              Suggested price uses {{ pct(grade.factor) }} of MSRP for {{ grade.label }}.
            </div>
          </div>
          <form id="list-form" class="flex items-center gap-2" @submit.prevent="act(unit, 'list', {price: forms.list})">
            <div class="relative">
              <span class="pointer-events-none absolute z-10 left-3 top-1/2 -translate-y-1/2 text-sm text-ink-3">$</span>
              <input v-model.trim="forms.list" class="input h-9 w-32 pl-6 num" inputmode="decimal" aria-label="List price" />
            </div>
            <button class="btn-sprout btn-sprout-primary"><Icon name="hero-shopping-bag" class="size-4" /> List on Amazon</button>
          </form>
        </div>

        <div v-else-if="unit.status === 'listed'" class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <div class="text-[14px] font-semibold text-ink">Live on Amazon for {{ unit.days_listed }} days</div>
            <div class="mt-0.5 text-[12.5px] text-ink-2">
              Adjust the price to move aging stock, or record an incoming order.
            </div>
          </div>
          <div class="flex items-center gap-2">
            <form id="reprice-form" class="flex items-center gap-2" @submit.prevent="act(unit, 'reprice', {price: forms.reprice})">
              <div class="relative">
                <span class="pointer-events-none absolute z-10 left-3 top-1/2 -translate-y-1/2 text-sm text-ink-3">$</span>
                <input v-model.trim="forms.reprice" class="input h-9 w-32 pl-6 num" inputmode="decimal" aria-label="List price" />
              </div>
              <button class="btn-sprout btn-sprout-ghost">Reprice</button>
            </form>
            <form
              id="sale-form"
              class="flex items-center gap-2 border-l border-line-soft pl-2"
              @submit.prevent="act(unit, 'sell', {price: forms.sale})"
            >
              <div class="relative">
                <span class="pointer-events-none absolute z-10 left-3 top-1/2 -translate-y-1/2 text-sm text-ink-3">$</span>
                <input v-model.trim="forms.sale" class="input h-9 w-32 pl-6 num" inputmode="decimal" aria-label="Sale price" />
              </div>
              <button class="btn-sprout btn-sprout-primary"><Icon name="hero-banknotes" class="size-4" /> Record sale</button>
            </form>
          </div>
        </div>

        <div v-else class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div class="flex items-center gap-3">
            <div class="grid size-9 place-items-center rounded-full bg-brand-700 text-white">
              <Icon name="hero-check" class="size-5" />
            </div>
            <div>
              <div class="text-[14px] font-semibold text-ink">Sold on {{ date(unit.sold_on) }}</div>
              <div class="mt-0.5 text-[12.5px] text-ink-2">
                Amazon order {{ unit.order_ref }} · {{ unit.days_in_stock }} days from receipt to sale.
              </div>
            </div>
          </div>
          <form id="close-sale-form" class="flex items-center gap-2" @submit.prevent>
            <input v-model.trim="forms.reason" placeholder="Reason (optional)" class="input h-9 w-48" aria-label="Reason" />
            <button type="button" class="btn-sprout btn-sprout-ghost" @click="act(unit, 'cancel_sale', {reason: forms.reason})">
              <Icon name="hero-x-circle" class="size-4" /> Cancel order
            </button>
            <button type="button" class="btn-sprout btn-sprout-ghost" @click="act(unit, 'return_sale', {reason: forms.reason})">
              <Icon name="hero-arrow-uturn-left" class="size-4" /> Mark returned
            </button>
          </form>
        </div>
      </div>
    </Card>

    <div class="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <div class="space-y-6 xl:col-span-2">
        <Card title="Bench work" :padded="false">
          <template #aside>
            {{ unit.bench.done }}/{{ unit.bench.total }} done · Completed
            <span id="bench-completed" class="num text-ink-2">{{ money(unit.bench.completed_cents) }}</span>
            · Pending <span id="bench-pending" class="num text-ink-2">{{ money(unit.bench.pending_cents) }}</span>
          </template>
          <div v-if="!unit.work_items.length" class="px-5 pb-2">
            <EmptyState icon="hero-wrench-screwdriver" title="No bench tasks yet">
              Tasks are added during inspection and refurbishment.
            </EmptyState>
          </div>
          <ul class="divide-y divide-line-soft">
            <li v-for="item in unit.work_items" :key="item.id" class="group flex items-center gap-3 px-5 py-3">
              <button
                type="button"
                :disabled="!editable"
                :class="[
                  'grid size-5 shrink-0 place-items-center rounded-md border transition-colors',
                  item.done ? 'border-brand-600 bg-brand-600 text-white' : 'border-line bg-white hover:border-brand-500',
                  editable && 'cursor-pointer',
                ]"
                aria-label="Toggle task"
                @click="toggleTask(item)"
              >
                <Icon v-if="item.done" name="hero-check-micro" class="size-3.5" />
              </button>
              <div class="min-w-0 flex-1">
                <div :class="['text-[13px]', item.done ? 'text-ink-2' : 'font-medium text-ink']">{{ item.description }}</div>
                <div class="text-[11.5px] text-ink-3">
                  {{ item.technician }} · {{ item.labor_minutes }} min labor{{
                    item.parts_cents > 0 ? ` · parts ${money(item.parts_cents)}` : ""
                  }}
                </div>
              </div>
              <div class="text-[13px] num">{{ money(item.cost_cents) }}</div>
              <button
                v-if="editable"
                type="button"
                class="cursor-pointer rounded p-1 text-ink-3 opacity-0 transition-opacity hover:text-[#b42318] focus:opacity-100 group-hover:opacity-100"
                aria-label="Remove task"
                @click="deleteTask(item)"
              >
                <Icon name="hero-trash-micro" class="size-4" />
              </button>
            </li>
          </ul>
          <form
            v-if="editable"
            id="bench-task-form"
            class="grid grid-cols-12 gap-2 border-t border-line-soft bg-[#fcfbf9] px-5 py-4 rounded-b-[14px]"
            @submit.prevent="addTask"
          >
            <input
              v-model.trim="task.description"
              placeholder="Add a bench task, e.g. Battery replacement"
              class="input col-span-12 h-9 md:col-span-5"
              aria-label="Task"
            />
            <select v-model="task.technician" class="select col-span-4 h-9 md:col-span-2" aria-label="Technician">
              <option v-for="name in boot.technicians" :key="name">{{ name }}</option>
            </select>
            <input v-model.trim="task.parts" placeholder="Parts $" inputmode="decimal" class="input col-span-3 h-9 md:col-span-2" aria-label="Parts" />
            <input v-model.trim="task.minutes" placeholder="Min" inputmode="numeric" class="input col-span-2 h-9 md:col-span-1" aria-label="Minutes" />
            <button class="btn-sprout btn-sprout-ghost col-span-3 justify-center md:col-span-2">
              <Icon name="hero-plus-micro" class="size-4" /> Add
            </button>
          </form>
        </Card>

        <Card v-if="unit.sales.length" id="unit-orders" title="Orders" :padded="false">
          <template #aside>Sales ledger · nothing is deleted</template>
          <ul class="divide-y divide-line-soft">
            <li v-for="sale in unit.sales" :id="`order-${sale.id}`" :key="sale.id" class="flex items-center gap-3 px-5 py-3 text-[13px]">
              <SaleStatus :status="sale.status" :label="sale.status_label" />
              <span class="font-mono text-[11.5px] text-ink-2 whitespace-nowrap">{{ sale.order_ref }}</span>
              <span class="text-ink-3">{{ date(sale.sold_on) }}</span>
              <span v-if="sale.closed_on" class="text-ink-3">
                → {{ sale.status_label }} {{ date(sale.closed_on) }}{{ sale.close_reason ? ` · ${sale.close_reason}` : "" }}
              </span>
              <span class="ml-auto num">{{ money(sale.price_cents) }}</span>
            </li>
          </ul>
        </Card>

        <Card id="unit-activity" title="Activity">
          <ol class="relative ml-1 space-y-5 border-l border-line pl-6">
            <li v-for="event in unit.events" :key="event.id" class="relative">
              <span class="absolute -left-[33px] top-0 grid size-[18px] place-items-center rounded-full bg-muted text-ink-2 ring-4 ring-white">
                <Icon :name="eventIcon(event.kind)" class="size-3" />
              </span>
              <div class="text-[13px] text-ink">{{ event.message }}</div>
              <div class="mt-0.5 text-[11.5px] text-ink-3">
                {{ dateTime(event.occurred_at, boot.time_zone) }}
              </div>
            </li>
          </ol>
        </Card>
      </div>

      <div class="space-y-6">
        <Card title="Unit economics">
          <dl class="space-y-2.5 text-[13px]">
            <div class="flex justify-between">
              <dt class="text-ink-2">{{ unit.status === "sold" ? "Sale price" : "List price" }}</dt>
              <dd class="num font-medium">{{ money(unit.economics.price_cents) }}</dd>
            </div>
            <div class="flex justify-between">
              <dt id="fees-label" class="text-ink-2">{{ estimated ? "Estimated fees" : "Amazon fees" }}</dt>
              <dd class="num">{{ unit.economics.fees_cents === null ? "—" : `−${money(unit.economics.fees_cents)}` }}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-ink-2">Acquisition cost</dt>
              <dd class="num">−{{ money(unit.acquisition_cost_cents) }}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-ink-2">Refurbishment (completed)</dt>
              <dd id="refurb-completed" class="num">−{{ money(unit.refurb_cost_cents) }}</dd>
            </div>
            <div v-if="unit.bench.pending_cents > 0" class="flex justify-between text-ink-3">
              <dt>Pending bench work · not in cost</dt>
              <dd id="refurb-pending" class="num">{{ money(unit.bench.pending_cents) }}</dd>
            </div>
          </dl>
          <div class="mt-4 flex items-end justify-between border-t border-line-soft pt-4">
            <div>
              <div id="profit-label" class="text-[11.5px] text-ink-3">
                {{ unit.status === "sold" ? "Realized profit" : "Projected profit" }}{{ est }}
              </div>
              <div :class="['mt-1 font-display text-[28px] leading-none num', unit.economics.profit_cents < 0 && 'text-[#b42318]']">
                {{ money(unit.economics.profit_cents) }}
              </div>
            </div>
            <div v-if="unit.economics.price_cents" class="text-right">
              <div id="margin-label" class="text-[11.5px] text-ink-3">Margin{{ est }}</div>
              <div class="mt-1 text-lg font-medium num">{{ pct(unit.economics.margin) }}</div>
            </div>
          </div>
          <div v-if="!unit.economics.price_cents" class="mt-3 rounded-lg bg-canvas px-3 py-2 text-xs text-ink-2">
            Suggested Renewed price for this grade:
            <span class="font-medium text-ink">{{ unit.grade ? money(unit.suggested_price_cents) : "grade first" }}</span>
          </div>
        </Card>

        <Card title="Details">
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-[13px]">
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">SKU</dt>
              <dd class="mt-0.5 truncate font-mono text-xs text-ink">{{ unit.sku }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">ASIN</dt>
              <dd class="mt-0.5 truncate font-mono text-xs text-ink">{{ unit.product.asin }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Purchase lot</dt>
              <dd class="mt-0.5 truncate text-ink">
                <RouterLink :to="`/purchasing/${unit.lot.id}`" class="text-brand-700 hover:underline">{{ unit.lot.reference }}</RouterLink>
              </dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Supplier</dt>
              <dd class="mt-0.5 truncate text-ink">{{ unit.lot.supplier }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Received</dt>
              <dd class="mt-0.5 truncate text-ink">{{ date(unit.received_on) }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Warehouse bin</dt>
              <dd class="mt-0.5 truncate text-ink">{{ unit.bin || "—" }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Listed</dt>
              <dd class="mt-0.5 truncate text-ink">{{ date(unit.listed_on) }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Sold</dt>
              <dd class="mt-0.5 truncate text-ink">{{ date(unit.sold_on) }}</dd>
            </div>
            <div v-if="unit.order_ref" class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">Amazon order</dt>
              <dd class="mt-0.5 truncate font-mono text-xs text-ink">{{ unit.order_ref }}</dd>
            </div>
            <div class="min-w-0">
              <dt class="text-[11.5px] text-ink-3">MSRP</dt>
              <dd class="mt-0.5 truncate text-ink">{{ money(unit.product.msrp_cents) }}</dd>
            </div>
          </dl>
        </Card>
      </div>
    </div>
  </template>
</template>
