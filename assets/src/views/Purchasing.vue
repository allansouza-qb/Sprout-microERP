<script setup>
import {computed, reactive, ref, watch} from "vue"
import {useRoute, useRouter} from "vue-router"

import {api} from "../api"
import Card from "../components/Card.vue"
import EstNote from "../components/EstNote.vue"
import Icon from "../components/Icon.vue"
import Modal from "../components/Modal.vue"
import PageHeader from "../components/PageHeader.vue"
import {date, money, moneyCompact, pct, signedPct} from "../format"
import {useLiveData} from "../realtime"
import {useToasts} from "../stores/toasts"

const route = useRoute()
const router = useRouter()
const toasts = useToasts()

const data = ref(null)
useLiveData(async () => (data.value = (await api.get("/lots")).data))

// ── Receive a lot (opens over this screen at /purchasing/new) ──────────────
const receiving = computed(() => route.path === "/purchasing/new")
const options = ref(null)
const form = reactive({supplier_id: "", purchased_on: "", total_cost: "", notes: "", lines: []})
const errors = ref([])
const saving = ref(false)

const blankLine = () => ({product_id: "", qty: 1})

watch(
  receiving,
  async (open) => {
    if (!open) return
    errors.value = []
    options.value = (await api.get("/lots/options")).data
    Object.assign(form, {
      supplier_id: "",
      purchased_on: options.value.today,
      total_cost: "",
      notes: "",
      lines: [blankLine()],
    })
  },
  {immediate: true},
)

const msrpTotal = computed(() => {
  const msrp = Object.fromEntries((options.value?.products || []).map((p) => [p.id, p.msrp_cents]))
  return form.lines.reduce((sum, line) => sum + (msrp[line.product_id] || 0) * Math.max(Number(line.qty) || 0, 0), 0)
})

function removeLine(index) {
  form.lines.splice(index, 1)
  if (!form.lines.length) form.lines.push(blankLine())
}

async function save() {
  if (saving.value) return
  saving.value = true
  errors.value = []

  try {
    const created = await api.post("/lots", form)
    toasts.info(created.message)
    router.push(`/purchasing/${created.data.id}`)
  } catch (e) {
    errors.value = e.messages
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <template v-if="data">
    <PageHeader title="Purchasing">
      <template #subtitle>
        Lots bought from liquidators, auctions and trade-in partners — and what each one returned.
      </template>
      <template #actions>
        <RouterLink to="/purchasing/new" class="btn-sprout btn-sprout-primary">
          <Icon name="hero-plus" class="size-4" /> Receive lot
        </RouterLink>
      </template>
    </PageHeader>

    <div class="mb-6 grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-3">
      <div
        v-for="supplier in data.suppliers.slice(0, 6)"
        :id="`supplier-${supplier.id}`"
        :key="supplier.id"
        class="card-surface fade-up p-4"
      >
        <div class="min-w-0">
          <div class="truncate text-[13.5px] font-semibold">{{ supplier.name }}</div>
          <div class="mt-0.5 text-[11.5px] text-ink-3">{{ supplier.kind_label }} · {{ supplier.location }}</div>
        </div>
        <div class="mt-6 grid grid-cols-3 gap-x-2 gap-y-3 text-[11.5px]">
          <div>
            <div class="text-ink-3">Lots</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ supplier.lots }}</div>
          </div>
          <div>
            <div class="text-ink-3">Units</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ supplier.units }}</div>
          </div>
          <div>
            <div class="text-ink-3">Spend</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ moneyCompact(supplier.spend) }}</div>
          </div>
          <div>
            <div class="text-ink-3">Revenue</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ moneyCompact(supplier.revenue) }}</div>
          </div>
          <div class="supplier-sell-through">
            <div class="text-ink-3">Sell-through</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ pct(supplier.sell_through) }}</div>
          </div>
          <div class="supplier-avg-margin">
            <div class="text-ink-3 whitespace-nowrap">Margin (est.)</div>
            <div class="mt-0.5 text-[15px] font-medium num">{{ pct(supplier.avg_margin) }}</div>
          </div>
        </div>
      </div>
    </div>

    <Card title="Purchase lots" :padded="false">
      <template #aside>{{ data.lots.length }} lots</template>
      <template #footer><EstNote id="est-note" /></template>
      <div class="overflow-x-auto mt-2">
        <table class="table-sprout table-compact">
          <thead>
            <tr>
              <th>Lot</th>
              <th>Supplier</th>
              <th class="max-[1439px]:hidden">Purchased</th>
              <th class="r">Units</th>
              <th class="r">Lot cost</th>
              <th>Sell-through</th>
              <th class="r">Net revenue (est.)</th>
              <th class="r">Realized ROI</th>
              <th class="r">Projected ROI</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="lot in data.lots" :key="lot.id" class="clickable" @click="router.push(`/purchasing/${lot.id}`)">
              <td class="font-medium whitespace-nowrap">{{ lot.reference }}</td>
              <td class="text-ink-2 whitespace-nowrap">{{ lot.supplier.name }}</td>
              <td class="text-ink-2 whitespace-nowrap max-[1439px]:hidden">{{ date(lot.purchased_on) }}</td>
              <td class="r num">{{ lot.stats.units }}</td>
              <td class="r num">{{ money(lot.total_cost_cents) }}</td>
              <td>
                <div class="flex items-center gap-2">
                  <div class="h-1.5 w-12 rounded-full bg-canvas">
                    <div class="h-full rounded-full bg-brand-500" :style="{width: `${lot.stats.sell_through * 100}%`}" />
                  </div>
                  <span class="text-[11.5px] text-ink-2 num">{{ Math.round(lot.stats.sell_through * 100) }}%</span>
                </div>
              </td>
              <td class="r num">{{ money(lot.stats.net) }}</td>
              <td :id="`lot-${lot.id}-realized-roi`" class="r num text-ink-2">
                {{ signedPct(lot.stats.realized_roi) }}
                <div class="text-[10.5px] text-ink-3">{{ lot.stats.realized_roi === null ? "no sales yet" : "to date" }}</div>
              </td>
              <td
                :id="`lot-${lot.id}-projected-roi`"
                :class="['r num font-medium', lot.stats.projected_roi < 0 ? 'text-[#b42318]' : 'text-brand-600']"
              >
                {{ signedPct(lot.stats.projected_roi) }}
                <div class="text-[10.5px] font-normal text-ink-3">
                  {{ lot.stats.sold === lot.stats.units ? "all sold" : `${lot.stats.units - lot.stats.sold} units open` }}
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Card>

    <Modal v-if="receiving && options" id="receive-lot" title="Receive a purchase lot" @close="router.push('/purchasing')">
      <template #subtitle>
        Cost is allocated across units in proportion to MSRP. Each unit gets a SKU and enters the workshop queue.
      </template>
      <form id="lot-form" class="space-y-6" @submit.prevent="save">
        <div class="form-section-title">Lot details</div>
        <div class="grid grid-cols-2 gap-3">
          <label class="col-span-2 block">
            <span class="mb-1 block text-xs font-medium text-ink-2">Supplier</span>
            <select v-model="form.supplier_id" name="supplier_id" class="select h-10 w-full" required>
              <option value="">Choose a supplier…</option>
              <option v-for="supplier in options.suppliers" :key="supplier.id" :value="supplier.id">
                {{ supplier.name }}
              </option>
            </select>
          </label>
          <label class="block">
            <span class="mb-1 block text-xs font-medium text-ink-2">Purchase date</span>
            <input v-model="form.purchased_on" type="date" name="purchased_on" class="input h-10 w-full" />
          </label>
          <label class="block">
            <span class="mb-1 block text-xs font-medium text-ink-2">Total lot cost (USD)</span>
            <div class="relative">
              <span class="pointer-events-none absolute z-10 left-3 top-1/2 -translate-y-1/2 text-sm text-ink-3">$</span>
              <input
                v-model.trim="form.total_cost"
                name="total_cost"
                placeholder="2,450.00"
                inputmode="decimal"
                class="input h-10 w-full pl-6 num"
                required
              />
            </div>
          </label>
        </div>

        <div>
          <div class="mb-1.5 flex items-center justify-between">
            <span class="form-section-title !mb-0">Items in this lot</span>
            <span class="text-[11.5px] text-ink-3 num">MSRP total {{ money(msrpTotal) }}</span>
          </div>
          <div class="space-y-2">
            <div v-for="(line, index) in form.lines" :key="index" class="lot-line flex items-center gap-2">
              <select v-model="line.product_id" class="select h-10 flex-1" aria-label="Product">
                <option value="">Choose a product…</option>
                <option v-for="product in options.products" :key="product.id" :value="product.id">
                  {{ product.brand }} {{ product.name }}
                </option>
              </select>
              <input v-model.number="line.qty" type="number" min="1" max="200" class="input h-10 w-20 num" aria-label="Quantity" />
              <button
                type="button"
                class="rounded-md p-2 text-ink-3 hover:bg-canvas hover:text-ink"
                aria-label="Remove line"
                @click="removeLine(index)"
              >
                <Icon name="hero-x-mark-micro" class="size-4" />
              </button>
            </div>
          </div>
          <button
            type="button"
            class="mt-2 inline-flex items-center gap-1 text-xs font-medium text-brand-700 hover:underline"
            @click="form.lines.push(blankLine())"
          >
            <Icon name="hero-plus-micro" class="size-3.5" /> Add another product
          </button>
        </div>

        <label class="block">
          <span class="form-section-title block">Notes</span>
          <textarea
            v-model="form.notes"
            name="notes"
            rows="2"
            class="textarea w-full"
            placeholder="Condition, manifest number, pallet notes…"
          ></textarea>
        </label>

        <div
          v-if="errors.length"
          id="lot-errors"
          role="alert"
          class="rounded-lg border border-[#f4c7c3] bg-[#fdf1ef] px-3 py-2 text-xs text-[#b42318]"
        >
          <div v-for="error in errors" :key="error">{{ error }}</div>
        </div>

        <div class="flex justify-end gap-2 border-t border-line-soft pt-4">
          <RouterLink to="/purchasing" class="btn-sprout btn-sprout-ghost">Cancel</RouterLink>
          <button type="submit" class="btn-sprout btn-sprout-primary" :disabled="saving">
            <Icon name="hero-inbox-arrow-down" class="size-4" /> {{ saving ? "Receiving…" : "Receive lot" }}
          </button>
        </div>
      </form>
    </Modal>
  </template>
</template>
