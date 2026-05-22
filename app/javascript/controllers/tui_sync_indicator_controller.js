import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase F1 child controller for `Tui::SyncIndicatorComponent`.
// Listens for the parent `tui-top-status-bar` controller's
// `tui:sync-changed` custom DOM event and patches the dot glyph + class
// + word text + class in place.
//
// Event contract:
//
//   detail: {
//     state:  "synced" | "syncing" | "disconnected",
//     target: "<optional label>" | null
//   }
//
// Word labels come from data-* values seeded by the VC (which sources
// them from `config/locales/tui/en.yml` `tui.tst.sync.*`) so the JS
// layer never inlines English strings.
//
// On disconnect we tear down the document-level listener so a Turbo
// morph doesn't double-fire.
export default class extends Controller {
  static targets = ["dot", "word", "target"]
  static values = {
    synced: String,
    syncing: String,
    disconnected: String
  }

  connect() {
    this.boundChanged = this.handleChanged.bind(this)
    document.addEventListener("tui:sync-changed", this.boundChanged)
  }

  disconnect() {
    if (this.boundChanged) {
      document.removeEventListener("tui:sync-changed", this.boundChanged)
      this.boundChanged = null
    }
  }

  handleChanged(event) {
    const detail = event?.detail || {}
    const state = detail.state || "synced"
    const target = detail.target || null
    this.apply(state, target)
  }

  apply(state, target) {
    if (this.hasDotTarget) {
      this.dotTarget.classList.remove(
        "sb-sync-dot--green",
        "sb-sync-dot--amber",
        "sb-sync-dot--red"
      )
    }
    if (this.hasWordTarget) {
      this.wordTarget.classList.remove(
        "sb-sync-word--idle",
        "sb-sync-word--syncing",
        "sb-sync-word--disconnected"
      )
    }

    let dotClass = "sb-sync-dot--green"
    let wordClass = "sb-sync-word--idle"
    let dotGlyph = "●"
    let wordText = this.syncedValue

    if (state === "syncing") {
      dotClass = "sb-sync-dot--amber"
      wordClass = "sb-sync-word--syncing"
      wordText = this.syncingValue
    } else if (state === "disconnected") {
      dotClass = "sb-sync-dot--red"
      wordClass = "sb-sync-word--disconnected"
      dotGlyph = "✗"
      wordText = this.disconnectedValue
    }

    if (this.hasDotTarget) {
      this.dotTarget.classList.add(dotClass)
      this.dotTarget.textContent = dotGlyph
    }
    if (this.hasWordTarget) {
      this.wordTarget.classList.add(wordClass)
      this.wordTarget.textContent = wordText
    }
    if (this.hasTargetTarget) {
      this.targetTarget.textContent = (state === "syncing" && target) ? target : ""
    }
  }
}
