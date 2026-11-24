import {defineStore} from "pinia"

let nextId = 1

// Short messages in the corner of the screen ("Sale recorded", errors…).
export const useToasts = defineStore("toasts", {
  state: () => ({items: []}),
  actions: {
    push(kind, text, ms = kind === "error" ? 7000 : 4000) {
      const id = nextId++
      // One message per kind at a time: a quick run of actions shows the latest, not a pile.
      this.items = [...this.items.filter((item) => item.kind !== kind), {id, kind, text}]
      setTimeout(() => this.dismiss(id), ms)
    },
    info(text) {
      this.push("info", text)
    },
    error(text) {
      this.push("error", text)
    },
    dismiss(id) {
      this.items = this.items.filter((item) => item.id !== id)
    },
  },
})
