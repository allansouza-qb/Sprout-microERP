<script setup>
import {statusLabel} from "../boot"

defineProps({status: {type: String, required: true}})

// received gray · inspecting/refurbishing amber · ready blue · listed purple · sold green
const styles = {
  received: ["bg-muted text-ink-2", "bg-ink-3"],
  inspecting: ["bg-[oklch(0.96_0.05_85)] text-[oklch(0.5_0.11_70)]", "bg-[oklch(0.75_0.15_75)]"],
  refurbishing: ["bg-[oklch(0.96_0.05_85)] text-[oklch(0.5_0.11_70)]", "bg-[oklch(0.75_0.15_75)]"],
  ready: ["bg-[oklch(0.95_0.03_250)] text-[oklch(0.48_0.13_255)]", "bg-[oklch(0.62_0.15_255)]"],
  listed: ["bg-[oklch(0.95_0.03_300)] text-[oklch(0.48_0.15_300)]", "bg-[oklch(0.62_0.17_300)]"],
  sold: ["bg-brand-100 text-brand-800", "bg-brand-500"],
}
</script>

<template>
  <span
    :class="[
      'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[11.5px] font-medium whitespace-nowrap',
      (styles[status] || ['bg-line text-ink-2'])[0],
    ]"
  >
    <span :class="['size-1.5 rounded-full', (styles[status] || [null, 'bg-ink-3'])[1]]" />{{ statusLabel(status) }}
  </span>
</template>
