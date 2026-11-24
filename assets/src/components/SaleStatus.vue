<script setup>
// Badge for a sales-ledger row.
defineProps({status: {type: String, required: true}, label: String})

const styles = {
  completed: "bg-brand-100 text-brand-700",
  cancelled: "bg-[#f1f2f4] text-[#4b5563]",
  returned: "bg-sand-100 text-[#8a6a36]",
}
</script>

<template>
  <span :class="['inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium whitespace-nowrap', styles[status]]">
    {{ label || status }}
  </span>
</template>
