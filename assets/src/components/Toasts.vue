<script setup>
import {useToasts} from "../stores/toasts"
import Icon from "./Icon.vue"

const toasts = useToasts()
</script>

<template>
  <div class="fixed right-4 top-4 z-[95] flex flex-col gap-2" aria-live="polite">
    <div
      v-for="toast in toasts.items"
      :key="toast.id"
      role="alert"
      :data-kind="toast.kind"
      class="toast-item fade-up flex w-80 sm:w-96 cursor-pointer items-start gap-3 rounded-xl border border-line bg-white p-4 text-sm text-ink shadow-[0_12px_32px_-12px_rgba(16,41,31,0.25)]"
      @click="toasts.dismiss(toast.id)"
    >
      <Icon v-if="toast.kind === 'info'" name="hero-check-circle" class="size-5 shrink-0 text-brand-600" />
      <Icon v-else name="hero-exclamation-circle" class="size-5 shrink-0 text-[#b42318]" />
      <p class="flex-1">{{ toast.text }}</p>
      <Icon name="hero-x-mark" class="size-5 opacity-40" />
    </div>
  </div>
</template>
