<script setup>
import {computed} from "vue"
import {pct} from "../format"
import Icon from "./Icon.vue"

// An indicator: small label, big number and, when there is one, the change
// against the previous period. `invert` marks figures where lower is better.
const props = defineProps({
  label: {type: String, required: true},
  value: {type: String, required: true},
  delta: {type: Number, default: null},
  invert: Boolean,
  hint: String,
})

const up = computed(() => props.delta >= 0)
const good = computed(() => (props.invert ? props.delta <= 0 : props.delta >= 0))
</script>

<template>
  <div class="card-surface kpi-card fade-up min-w-0 p-5">
    <span class="text-[11px] font-medium uppercase tracking-[0.08em] text-ink-2">{{ label }}</span>
    <div class="kpi-value mt-2.5 text-[28px] font-extrabold leading-none tracking-[-0.02em] text-ink num">
      {{ value }}
    </div>
    <div class="mt-2.5 flex items-center gap-1.5 text-xs">
      <span
        v-if="delta !== null"
        :class="['inline-flex items-center gap-0.5 font-medium num', good ? 'text-brand-600' : 'text-[#b42318]']"
      >
        <Icon :name="up ? 'hero-arrow-up-right-mini' : 'hero-arrow-down-right-mini'" class="size-3.5" />
        {{ pct(Math.abs(delta)) }}
      </span>
      <span class="text-ink-3">{{ hint }}</span>
    </div>
  </div>
</template>
