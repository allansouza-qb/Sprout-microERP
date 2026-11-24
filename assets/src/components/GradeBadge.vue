<script setup>
import {gradeShort} from "../boot"
import Icon from "./Icon.vue"

defineProps({grade: String})

const styles = {
  premium: "border-sand-500/30 bg-sand-100 text-[#8a6a36]",
  excellent: "border-brand-200 bg-brand-50 text-brand-700",
  good: "border-line bg-white text-ink-2",
  acceptable: "border-line bg-canvas text-ink-3",
}
</script>

<template>
  <span v-if="!grade" class="text-xs text-ink-3">—</span>
  <span
    v-else
    :class="[
      'inline-flex items-center gap-1 rounded-md border px-1.5 py-0.5 text-[11px] font-medium whitespace-nowrap',
      styles[grade],
    ]"
  >
    <Icon v-if="grade === 'premium'" name="hero-sparkles-micro" class="size-3" />
    {{ gradeShort(grade) }}
  </span>
</template>
