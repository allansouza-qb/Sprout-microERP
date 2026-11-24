<script setup>
// The frame around every screen: the page content and the dock, a floating
// bar at the bottom that is the app's only menu.
import {computed, onMounted, onUnmounted} from "vue"
import {useRoute} from "vue-router"

import {magnifyDock} from "../dock"
import {items} from "../nav"
import Icon from "./Icon.vue"
import LogoMark from "./LogoMark.vue"
import Toasts from "./Toasts.vue"

const route = useRoute()
const current = computed(() => route.meta.nav)

onMounted(() => document.addEventListener("mousemove", magnifyDock))
onUnmounted(() => document.removeEventListener("mousemove", magnifyDock))
</script>

<template>
  <div class="app-shell min-h-screen overflow-x-clip">
    <main class="app-main mx-auto max-w-[1320px] px-4 py-8 sm:px-8 lg:px-10 lg:py-10">
      <slot />
    </main>
  </div>

  <nav class="app-dock" aria-label="Main">
    <RouterLink to="/" class="dock-logo" title="Sprout"><LogoMark class="size-9" /></RouterLink>
    <span class="dock-sep"></span>
    <RouterLink
      v-for="item in items"
      :key="item.key"
      :to="item.path"
      :class="['dock-item', current === item.key && 'active']"
      :aria-current="current === item.key ? 'page' : undefined"
    >
      <Icon :name="item.icon" class="dock-icon" />
      <span class="dock-tip">{{ item.label }}</span>
    </RouterLink>
  </nav>

  <Toasts />
</template>
