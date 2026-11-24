<script setup>
defineProps({title: {type: String, required: true}})
</script>

<template>
  <div class="mb-6 flex flex-col gap-4 border-b border-line pb-6 sm:flex-row sm:items-start sm:justify-between fade-up">
    <div class="min-w-0">
      <div v-if="$slots.crumbs" class="mb-3 flex items-center gap-1.5 text-xs text-ink-3">
        <slot name="crumbs" />
      </div>
      <h1 class="text-[30px] font-extrabold leading-tight tracking-[-0.03em] text-ink">{{ title }}</h1>
      <p v-if="$slots.subtitle" class="mt-1 text-sm text-ink-2"><slot name="subtitle" /></p>
    </div>
    <div v-if="$slots.actions" class="flex shrink-0 items-center gap-2 sm:pt-0.5">
      <slot name="actions" />
    </div>
  </div>
</template>
