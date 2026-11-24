<script setup>
import Icon from "./Icon.vue"

defineProps({product: {type: Object, required: true}, sub: String})
</script>

<template>
  <div class="flex items-center gap-3 min-w-0">
    <div class="grid size-8 shrink-0 place-items-center rounded-lg bg-muted text-ink-2">
      <Icon :name="product.icon" class="size-4" />
    </div>
    <div class="min-w-0">
      <div class="truncate font-medium text-ink">{{ product.brand }} {{ product.name }}</div>
      <div class="truncate text-xs text-ink-3">{{ sub || product.category }}</div>
    </div>
  </div>
</template>
