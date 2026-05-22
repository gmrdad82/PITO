import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase F1 child controller for `Tui::SidekiqStatsComponent`.
// Listens for the parent `tui-top-status-bar` controller's
// `tui:sidekiq-changed` custom DOM event and patches the three
// queue-depth cells in place.
//
// Event contract:
//
//   detail: { busy: <int>, enqueued: <int>, retry: <int> }
//
// Color rules (locked 2026-05-22):
//
//   busy > 0      → .sk-b (success / green)
//   enqueued > 0  → .sk-e (muted)
//   retry > 0     → .sk-r (danger / pink)
//   any count 0   → .sk-zero (muted)
//
// Letter prefixes (`b` / `e` / `r`) come from data-* values seeded by
// the VC (sourced from `config/locales/tui/en.yml`
// `tui.tst.sidekiq.*_prefix`) so the JS layer never inlines English.
export default class extends Controller {
  static targets = ["busy", "enqueued", "retry"]
  static values = {
    busyPrefix: String,
    enqueuedPrefix: String,
    retryPrefix: String
  }

  connect() {
    this.boundChanged = this.handleChanged.bind(this)
    document.addEventListener("tui:sidekiq-changed", this.boundChanged)
  }

  disconnect() {
    if (this.boundChanged) {
      document.removeEventListener("tui:sidekiq-changed", this.boundChanged)
      this.boundChanged = null
    }
  }

  handleChanged(event) {
    const detail = event?.detail || {}
    if (detail.busy !== undefined && this.hasBusyTarget) {
      this.updateCell(this.busyTarget, this.busyPrefixValue, detail.busy, "sk-b")
    }
    if (detail.enqueued !== undefined && this.hasEnqueuedTarget) {
      this.updateCell(this.enqueuedTarget, this.enqueuedPrefixValue, detail.enqueued, "sk-e")
    }
    if (detail.retry !== undefined && this.hasRetryTarget) {
      this.updateCell(this.retryTarget, this.retryPrefixValue, detail.retry, "sk-r")
    }
  }

  updateCell(el, prefix, value, nonZeroClass) {
    const n = Number(value)
    const safe = Number.isFinite(n) ? n : 0
    el.textContent = `${prefix}${safe}`
    if (safe === 0) {
      el.classList.add("sk-zero")
      el.classList.remove(nonZeroClass)
    } else {
      el.classList.remove("sk-zero")
      el.classList.add(nonZeroClass)
    }
  }
}
