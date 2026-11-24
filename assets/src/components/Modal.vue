<script setup>
import {onBeforeUnmount, onMounted} from "vue"
import Icon from "./Icon.vue"

defineProps({title: {type: String, required: true}})
const emit = defineEmits(["close"])

const onKey = (e) => e.key === "Escape" && emit("close")
onMounted(() => window.addEventListener("keydown", onKey))
onBeforeUnmount(() => window.removeEventListener("keydown", onKey))
</script>

<template>
  <div class="fixed inset-0 z-[70] flex items-start justify-center overflow-y-auto px-4 py-12 sm:py-20">
    <div class="fixed inset-0 bg-brand-950/30 backdrop-blur-[2px]" aria-hidden="true" @click="emit('close')" />
    <div class="relative w-full max-w-xl card-surface fade-up shadow-2xl" role="dialog" aria-modal="true">
      <div class="flex items-start justify-between gap-4 border-b border-line-soft px-6 py-5">
        <div>
          <h2 class="font-display text-[20px] leading-tight">{{ title }}</h2>
          <p v-if="$slots.subtitle" class="mt-1 text-sm text-ink-2"><slot name="subtitle" /></p>
        </div>
        <button
          type="button"
          class="rounded-md p-1 text-ink-3 hover:bg-canvas hover:text-ink"
          aria-label="Close"
          @click="emit('close')"
        >
          <Icon name="hero-x-mark" class="size-5" />
        </button>
      </div>
      <div class="px-6 py-5"><slot /></div>
    </div>
  </div>
</template>
