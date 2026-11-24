<script setup>
defineProps({title: String, padded: {type: Boolean, default: true}})
</script>

<template>
  <section class="card-surface fade-up min-w-0">
    <div v-if="title" class="flex items-center justify-between gap-3 px-5 pt-4 pb-1">
      <h2 class="text-[13.5px] font-semibold text-ink">{{ title }}</h2>
      <div v-if="$slots.aside" class="text-xs text-ink-3"><slot name="aside" /></div>
    </div>
    <div :class="padded && 'p-5'"><slot /></div>
    <div v-if="$slots.footer" class="border-t border-line-soft px-5 py-3 text-xs text-ink-3">
      <slot name="footer" />
    </div>
  </section>
</template>
