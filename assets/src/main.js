// Sprout ERP — single-page app. Phoenix serves the HTML shell and the JSON
// API; this bundle renders every screen.
import "../css/app.css"

import {createPinia} from "pinia"
import {createApp} from "vue"

import App from "./App.vue"
import {connect} from "./realtime"
import {router} from "./router"

const app = createApp(App).use(createPinia()).use(router)

// Mount once the first route is known, so the right dock icon is lit from the start.
router.isReady().then(() => app.mount("#app"))

connect()
