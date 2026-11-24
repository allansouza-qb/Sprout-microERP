<script setup>
import {computed} from "vue"
import {statuses} from "../boot"

// The six stages of a unit, with the current one highlighted.
const props = defineProps({status: {type: String, required: true}})
const current = computed(() => statuses.findIndex((s) => s.key === props.status))
</script>

<template>
  <ol class="grid grid-cols-6 gap-2">
    <li v-for="(stage, i) in statuses" :key="stage.key" class="min-w-0">
      <div :class="['h-1.5 rounded-full', i < current ? 'bg-brand-500' : i === current ? 'bg-brand-700' : 'bg-line']" />
      <div :class="['mt-2 truncate text-[11.5px]', i <= current ? 'font-medium text-ink' : 'text-ink-3']">
        {{ stage.label }}
      </div>
    </li>
  </ol>
</template>
