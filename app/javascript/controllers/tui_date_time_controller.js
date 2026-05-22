import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase F1 child controller for `Tui::DateTimeComponent`.
// Ticks once per second to keep the wall clock current, and runs a
// ~500ms digit-scramble effect at every 00:00:00 (browser-local)
// rollover. The scramble fills both date + time slots with random
// ASCII digits at ~60ms per frame, then settles on the new day's
// real value.
//
// Format: `Fri, May 22 · 01:30:46` — derived locally via
// `Intl.DateTimeFormat` would also work, but a manual format keeps the
// substring stable for the scramble routine.
//
// Lifecycle:
//   connect()    — render once, schedule 1Hz tick, capture starting day
//   tick()       — update once per second; detect day rollover; start
//                  scramble if rolled
//   disconnect() — clear timers (1Hz tick + scramble frame)
export default class extends Controller {
  static WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  static MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  static SCRAMBLE_DURATION_MS = 500
  static SCRAMBLE_FRAME_MS = 60

  connect() {
    const now = new Date()
    this.lastDay = now.getDate()
    this.render(now)
    this.tickTimer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.tickTimer) {
      clearInterval(this.tickTimer)
      this.tickTimer = null
    }
    this.stopScramble()
  }

  tick() {
    const now = new Date()
    const today = now.getDate()
    if (today !== this.lastDay) {
      this.lastDay = today
      this.startScramble(now)
      return
    }
    if (this.scrambleTimer) return // scramble in flight; let it finish
    this.render(now)
  }

  render(now) {
    const ctor = this.constructor
    const weekday = ctor.WEEKDAYS[now.getDay()]
    const month = ctor.MONTHS[now.getMonth()]
    const day = now.getDate()
    const hh = String(now.getHours()).padStart(2, "0")
    const mm = String(now.getMinutes()).padStart(2, "0")
    const ss = String(now.getSeconds()).padStart(2, "0")
    this.element.textContent = `${weekday}, ${month} ${day} · ${hh}:${mm}:${ss}`
  }

  startScramble(targetTime) {
    const ctor = this.constructor
    const targetText = this.format(targetTime)
    const startedAt = Date.now()
    this.stopScramble()
    this.scrambleTimer = setInterval(() => {
      const elapsed = Date.now() - startedAt
      if (elapsed >= ctor.SCRAMBLE_DURATION_MS) {
        this.stopScramble()
        this.element.textContent = targetText
        return
      }
      this.element.textContent = this.scrambleDigits(targetText)
    }, ctor.SCRAMBLE_FRAME_MS)
  }

  stopScramble() {
    if (this.scrambleTimer) {
      clearInterval(this.scrambleTimer)
      this.scrambleTimer = null
    }
  }

  format(now) {
    const ctor = this.constructor
    const weekday = ctor.WEEKDAYS[now.getDay()]
    const month = ctor.MONTHS[now.getMonth()]
    const day = now.getDate()
    const hh = String(now.getHours()).padStart(2, "0")
    const mm = String(now.getMinutes()).padStart(2, "0")
    const ss = String(now.getSeconds()).padStart(2, "0")
    return `${weekday}, ${month} ${day} · ${hh}:${mm}:${ss}`
  }

  // Replace every ASCII digit (0-9) in `text` with a random digit. All
  // other characters (letters, punctuation, spaces, the · separator)
  // pass through untouched so the visual shape stays stable.
  scrambleDigits(text) {
    let out = ""
    for (const ch of text) {
      if (ch >= "0" && ch <= "9") {
        out += String(Math.floor(Math.random() * 10))
      } else {
        out += ch
      }
    }
    return out
  }
}
