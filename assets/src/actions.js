// Runs an action on a unit through the API and reports the outcome.
//
// Every request carries the `lock_version` the screen is showing; when
// someone else changed the unit first the API answers 409, and the screen
// says so and reloads instead of applying the action twice.
import {api} from "./api"
import {useToasts} from "./stores/toasts"

export function useUnitActions(reload) {
  const toasts = useToasts()

  async function run(request, prefix = "") {
    try {
      const result = await request()
      if (result?.message) toasts.info(prefix + result.message)
      await reload(result?.data)
      return result?.data ?? true
    } catch (error) {
      toasts.error(error.message)
      if (error.stale) await reload()
      return null
    }
  }

  /** POST /api/units/:id/actions/:action — body may carry grade, price or reason. */
  const act = (unit, action, body = {}, prefix = "") =>
    run(() => api.post(`/units/${unit.id}/actions/${action}`, {...body, version: unit.lock_version}), prefix)

  return {act, run}
}
