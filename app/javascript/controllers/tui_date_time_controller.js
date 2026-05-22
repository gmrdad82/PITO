import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase F1 child controller for `Tui::DateTimeComponent`.
// Ticks once per second to keep the wall clock current. The visible
// string is `Fri, May 22 · 01:30:46`; the day rolls over silently at
// midnight (just whatever the next 1Hz tick renders), no animation.
//
// (2026-05-22 — the original midnight scramble effect that ran for
// ~500ms at every 00:00:00 local rollover was deleted. User decided
// the animation was unnecessary; the clock simply ticks forward and
// the date label updates on the next tick after midnight.)
//
// Lifecycle:
//   connect()    — render once, schedule 1Hz tick
//   tick()       — re-render once per second
//   disconnect() — clear the 1Hz timer
//
// 2026-05-22 — Now also reacts to `tui:notifications-changed` (document
// event, fanned out by `tui-status-bar` on the `notifications` kind).
// When `future_count > 0` the root span gains the
// `.dt-has-future-notif` class so its text color flips to the Home
// section accent (Dracula Purple). When `future_count === 0` the class
// is removed and the clock returns to the default muted color. The
// listener is registered via Stimulus `data-action` wiring in the
// template (declarative, no manual addEventListener needed).
export default class extends Controller {
  static WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  static MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  static FUTURE_NOTIF_CLASS = "dt-has-future-notif"

  connect() {
    this.render(new Date())
    this.tickTimer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.tickTimer) {
      clearInterval(this.tickTimer)
      this.tickTimer = null
    }
  }

  // Stimulus action handler — wired via `data-action` in the template:
  //   tui:notifications-changed@document->tui-date-time#onNotificationsChanged
  // Toggles the future-notification color class based on the broadcast
  // count. A missing / non-numeric / negative count is treated as 0
  // (no purple).
  onNotificationsChanged(event) {
    const ctor = this.constructor
    const raw = event?.detail?.future_count
    const count = Number(raw)
    const hasFuture = Number.isFinite(count) && count > 0
    if (hasFuture) {
      this.element.classList.add(ctor.FUTURE_NOTIF_CLASS)
    } else {
      this.element.classList.remove(ctor.FUTURE_NOTIF_CLASS)
    }
  }

  tick() {
    this.render(new Date())
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
}
