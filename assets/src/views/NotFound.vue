<script setup>
import EmptyState from "../components/EmptyState.vue"
</script>

<template>
  <EmptyState icon="hero-map" title="This page does not exist">
    <RouterLink to="/" class="text-brand-700 hover:underline">Back to the dashboard</RouterLink>
  </EmptyState>
</template>
