// Dock: the icons grow as the pointer gets close to them.
let frame = 0

export function magnifyDock(event) {
  if (frame) return
  frame = requestAnimationFrame(() => {
    frame = 0
    const dock = document.querySelector(".app-dock")
    if (!dock) return
    const box = dock.getBoundingClientRect()
    const near = event.clientY > box.top - 36 && event.clientX > box.left - 40 && event.clientX < box.right + 40
    dock.querySelectorAll(".dock-item").forEach((item) => {
      let scale = 1
      if (near) {
        const b = item.getBoundingClientRect()
        const distance = Math.abs(event.clientX - (b.left + b.width / 2))
        scale = 1 + 0.5 * Math.max(0, 1 - distance / 140) ** 1.5
      }
      item.style.setProperty("--s", scale.toFixed(3))
    })
  })
}
