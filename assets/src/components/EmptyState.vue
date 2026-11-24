<script setup>
import Icon from "./Icon.vue"

defineProps({icon: {type: String, default: "hero-inbox"}, title: {type: String, required: true}})
</script>

<template>
  <div class="flex flex-col items-center justify-center px-6 py-14 text-center">
    <div class="grid size-11 place-items-center rounded-full bg-brand-50 text-brand-600">
      <Icon :name="icon" class="size-5" />
    </div>
    <div class="mt-3 text-sm font-medium text-ink">{{ title }}</div>
    <div class="mt-1 text-xs text-ink-3"><slot /></div>
  </div>
</template>
