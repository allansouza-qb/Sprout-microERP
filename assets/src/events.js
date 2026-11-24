// Icon for each kind of history event.
const icons = {
  sold: "hero-banknotes-micro",
  sale_cancelled: "hero-x-circle-micro",
  sale_returned: "hero-arrow-uturn-left-micro",
  listed: "hero-shopping-bag-micro",
  repriced: "hero-tag-micro",
  qc: "hero-check-badge-micro",
  graded: "hero-star-micro",
  bench: "hero-wrench-micro",
  inspection: "hero-magnifying-glass-micro",
}

export const eventIcon = (kind) => icons[kind] || "hero-inbox-arrow-down-micro"
