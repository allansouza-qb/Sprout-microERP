// Data rendered by Phoenix into the page shell (PageController): the company
// time zone and the fixed vocabularies (stages, grades, categories, technicians).
const el = typeof document !== "undefined" ? document.getElementById("boot") : null

export const boot = el ? JSON.parse(el.textContent) : {}

export const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content

const byKey = (list) => Object.fromEntries((list || []).map((item) => [item.key, item]))

export const statuses = boot.statuses || []
export const grades = boot.grades || []
export const statusLabel = (key) => byKey(statuses)[key]?.label ?? key
export const gradeLabel = (key) => byKey(grades)[key]?.label ?? "Ungraded"
export const gradeShort = (key) => byKey(grades)[key]?.short ?? gradeLabel(key)
