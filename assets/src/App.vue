<script setup>
import {useRoute} from "vue-router"
import AppShell from "./components/AppShell.vue"

const route = useRoute()
</script>

<template>
  <AppShell>
    <RouterView :key="route.meta.view || route.path" />
  </AppShell>
</template>
