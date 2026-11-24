import {createRouter, createWebHistory} from "vue-router"

import Dashboard from "./views/Dashboard.vue"
import Inventory from "./views/Inventory.vue"
import Listings from "./views/Listings.vue"
import Lot from "./views/Lot.vue"
import NotFound from "./views/NotFound.vue"
import Purchasing from "./views/Purchasing.vue"
import Sales from "./views/Sales.vue"
import Unit from "./views/Unit.vue"
import Workshop from "./views/Workshop.vue"

// `nav` highlights the menu entry; `view` keeps a screen mounted across routes
// that only open something on top of it (the receive-lot form).
const routes = [
  {path: "/", component: Dashboard, meta: {nav: "dashboard", title: "Dashboard"}},
  {path: "/purchasing", component: Purchasing, meta: {nav: "purchasing", title: "Purchasing", view: "purchasing"}},
  {path: "/purchasing/new", component: Purchasing, meta: {nav: "purchasing", title: "Receive lot", view: "purchasing"}},
  {path: "/purchasing/:id(\\d+)", component: Lot, props: true, meta: {nav: "purchasing", title: "Purchasing"}},
  {path: "/workshop", component: Workshop, meta: {nav: "workshop", title: "Workshop"}},
  {path: "/inventory", component: Inventory, meta: {nav: "inventory", title: "Inventory"}},
  {path: "/inventory/:id(\\d+)", component: Unit, props: true, meta: {nav: "inventory", title: "Inventory"}},
  {path: "/listings", component: Listings, meta: {nav: "listings", title: "Amazon listings"}},
  {path: "/sales", component: Sales, meta: {nav: "sales", title: "Sales"}},
  {path: "/:pathMatch(.*)*", component: NotFound, meta: {title: "Not found"}},
]

export const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: (to, from, saved) => saved || (to.path === from.path ? undefined : {top: 0}),
})

export const setTitle = (title) => (document.title = title ? `${title} · Sprout ERP` : "Sprout ERP")

router.afterEach((to) => setTitle(to.meta.title))
