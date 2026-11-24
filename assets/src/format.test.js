import {describe, expect, it} from "vitest"
import {ago, date, dateTime, money, moneyCompact, moneyShort, pct, shortDate, signedPct} from "./format"

describe("money", () => {
  it("formats cents like the backend", () => {
    expect(money(123456)).toBe("$1,234.56")
    expect(money(5)).toBe("$0.05")
    expect(money(0)).toBe("$0.00")
    expect(money(-1048)).toBe("−$10.48")
    expect(money(null)).toBe("—")
    expect(money(undefined)).toBe("—")
  })

  it("rounds whole-dollar and compact amounts", () => {
    expect(moneyShort(2915242)).toBe("$29,152")
    expect(moneyShort(149)).toBe("$1")
    expect(moneyShort(150)).toBe("$2")
    expect(moneyShort(-902325)).toBe("−$9,023")
    expect(moneyCompact(1_240_000)).toBe("$12.4k")
    expect(moneyCompact(150_000_000)).toBe("$1.5M")
    expect(moneyCompact(99_900)).toBe("$999")
  })
})

describe("percentages", () => {
  it("keeps one decimal and shows a dash for missing values", () => {
    expect(pct(0.31)).toBe("31.0%")
    expect(pct(0)).toBe("0.0%")
    expect(pct(null)).toBe("—")
    expect(signedPct(0.263)).toBe("+26.3%")
    expect(signedPct(-0.674)).toBe("-67.4%")
    expect(signedPct(null)).toBe("—")
  })
})

describe("dates", () => {
  it("shows business dates without shifting them across time zones", () => {
    expect(date("2026-11-01")).toBe("Nov 1, 2026")
    expect(shortDate("2026-01-09")).toBe("Jan 9")
    expect(date(null)).toBe("—")
  })

  it("shows timestamps in the company time zone", () => {
    expect(dateTime("2026-11-24T13:05:00Z", "America/Sao_Paulo")).toBe("Nov 24, 2026 · 10:05")
    // 01:30 UTC on the 25th is still the 24th in São Paulo
    expect(dateTime("2026-11-25T01:30:00Z", "America/Sao_Paulo")).toBe("Nov 24, 2026 · 22:30")
    expect(dateTime("2026-11-24T16:00:00Z", "Asia/Tokyo")).toBe("Nov 25, 2026 · 01:00")
  })

  it("describes how long ago something happened", () => {
    const now = Date.parse("2026-11-24T12:00:00Z")
    const zone = "America/Sao_Paulo"
    expect(ago("2026-11-24T11:59:30Z", zone, now)).toBe("just now")
    expect(ago("2026-11-24T11:15:00Z", zone, now)).toBe("45m ago")
    expect(ago("2026-11-24T05:00:00Z", zone, now)).toBe("7h ago")
    expect(ago("2026-11-21T12:00:00Z", zone, now)).toBe("3d ago")
    expect(ago("2026-11-02T01:00:00Z", zone, now)).toBe("Nov 1")
  })
})
