// Display formatting. Amounts arrive as integer cents and dates as ISO strings;
// business dates are plain days, timestamps are shown in the company time zone.
const MINUS = "−"
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

const group = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
const missing = (v) => v === null || v === undefined

/** 123456 -> "$1,234.56"; negatives use a real minus sign; null -> "—". */
export function money(cents) {
  if (missing(cents)) return "—"
  const abs = Math.abs(Math.round(cents))
  return `${cents < 0 ? MINUS : ""}$${group(Math.floor(abs / 100))}.${String(abs % 100).padStart(2, "0")}`
}

/** Whole dollars for indicators and charts: 123456 -> "$1,235". */
export function moneyShort(cents) {
  if (missing(cents)) return "—"
  const rounded = Math.round(cents)
  return `${rounded < 0 ? MINUS : ""}$${group(Math.floor((Math.abs(rounded) + 50) / 100))}`
}

/** 1240000 -> "$12.4k". */
export function moneyCompact(cents) {
  const dollars = cents / 100
  if (Math.abs(dollars) >= 1_000_000) return `$${(dollars / 1_000_000).toFixed(1)}M`
  if (Math.abs(dollars) >= 1_000) return `$${(dollars / 1_000).toFixed(1)}k`
  return `$${Math.round(dollars)}`
}

/** 0.3104 -> "31.0%"; null -> "—". */
export const pct = (ratio) => (missing(ratio) ? "—" : `${(ratio * 100).toFixed(1)}%`)

/** Like pct, with an explicit + for gains (ROI). */
export const signedPct = (ratio) => (missing(ratio) ? "—" : (ratio >= 0 ? "+" : "") + pct(ratio))

export const decimal = (n, digits = 1) => (missing(n) ? "—" : Number(n).toFixed(digits))

const parts = (iso) => iso.slice(0, 10).split("-").map(Number)

/** "2026-11-23" -> "Nov 23, 2026" (a business date: no time zone involved). */
export function date(iso) {
  if (!iso) return "—"
  const [y, m, d] = parts(iso)
  return `${MONTHS[m - 1]} ${d}, ${y}`
}

/** "2026-11-23" -> "Nov 23". */
export function shortDate(iso) {
  if (!iso) return "—"
  const [, m, d] = parts(iso)
  return `${MONTHS[m - 1]} ${d}`
}

const zoned = (iso, timeZone) => {
  const fields = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(iso))

  return Object.fromEntries(fields.map((f) => [f.type, f.value]))
}

/** UTC timestamp -> "Nov 24, 2026 · 10:05" in the company time zone. */
export function dateTime(iso, timeZone) {
  if (!iso) return "—"
  const f = zoned(iso, timeZone)
  return `${MONTHS[f.month - 1]} ${Number(f.day)}, ${f.year} · ${f.hour}:${f.minute}`
}

/** "just now", "5m ago", "3h ago", "2d ago", then the date in the company zone. */
export function ago(iso, timeZone, now = Date.now()) {
  const seconds = Math.floor((now - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return "just now"
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
  if (seconds < 86_400) return `${Math.floor(seconds / 3600)}h ago`
  if (seconds < 86_400 * 7) return `${Math.floor(seconds / 86_400)}d ago`
  const f = zoned(iso, timeZone)
  return `${MONTHS[f.month - 1]} ${Number(f.day)}`
}

export const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`
