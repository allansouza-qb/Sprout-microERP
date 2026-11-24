// Realtime: the server pushes "changed" on the "inventory" channel whenever
// stock changes, and screens refetch through the API. The channel carries no
// data on purpose.
import {onMounted, ref, watch} from "vue"
import {Socket} from "phoenix"

export const tick = ref(0)

let socket = null

export function connect() {
  if (socket) return
  socket = new Socket("/socket")
  socket.connect()

  const channel = socket.channel("inventory")
  channel.on("changed", () => tick.value++)
  // After a reconnect something may have changed while we were away.
  channel.join().receive("ok", () => tick.value++)
}

/**
 * Loads a screen's data now and again whenever inventory changes.
 * Returns {loading, failed, reload}.
 */
export function useLiveData(load) {
  const loading = ref(true)
  const failed = ref(null)
  let timer = null

  const reload = async () => {
    try {
      await load()
      failed.value = null
    } catch (error) {
      failed.value = error
    } finally {
      loading.value = false
    }
  }

  onMounted(reload)
  // A burst of changes (e.g. receiving a lot) becomes a single refetch.
  watch(tick, () => {
    clearTimeout(timer)
    timer = setTimeout(reload, 120)
  })

  return {loading, failed, reload}
}
