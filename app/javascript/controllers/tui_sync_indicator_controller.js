import { Controller } from "@hotwired/stimulus"

/**
 * tui-sync-indicator — Stimulus controller for Tui::SyncIndicatorComponent.
 *
 * Renders the word "sync" in one of three color states:
 *
 *   synced       → muted, no animation
 *   syncing      → accent, shimmer
 *   disconnected → danger (red), no animation
 *
 * NO brackets, NO glyphs — color + animation are the only differentiators.
 *
 * State transitions are driven by document events:
 *
 *   tui:cable-activity    → "syncing" (debounced back to "synced" after SETTLE_MS)
 *   tui:sync-changed      → "disconnected" or "synced" on cable lifecycle events
 *
 * The 4 letters of "sync" scramble (8 frames × 30 ms = 240 ms) on every
 * state change. Same scramble cadence as sessions_scramble_controller.js.
 *
 * @see app/components/tui/sync_indicator_component.rb
 */

const SCRAMBLE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
const FINAL_TEXT = "sync"
const SCRAMBLE_FRAMES = 8
const FRAME_INTERVAL_MS = 30

function randomChar() {
  return SCRAMBLE_CHARS[Math.floor(Math.random() * SCRAMBLE_CHARS.length)]
}

/** Scramble all 4 letters of `element.textContent` for SCRAMBLE_FRAMES frames,
 *  then settle to FINAL_TEXT. Returns the interval id so the caller can cancel. */
function scrambleWord(element, onDone) {
  let frame = 0
  const interval = setInterval(() => {
    frame++
    if (frame >= SCRAMBLE_FRAMES) {
      clearInterval(interval)
      element.textContent = FINAL_TEXT
      if (onDone) onDone()
    } else {
      // Replace each char with a random one for the intermediate frames.
      element.textContent = Array.from(FINAL_TEXT, () => randomChar()).join("")
    }
  }, FRAME_INTERVAL_MS)
  return interval
}

export default class extends Controller {
  static values = { state: { type: String, default: "synced" } }
  static SETTLE_MS = 300

  connect() {
    this._onActivity = this.handleActivity.bind(this)
    this._onSyncChanged = this.handleSyncChanged.bind(this)
    document.addEventListener("tui:cable-activity", this._onActivity)
    document.addEventListener("tui:sync-changed", this._onSyncChanged)
    this._settleTimer = null
    this._scrambleInterval = null
  }

  disconnect() {
    document.removeEventListener("tui:cable-activity", this._onActivity)
    document.removeEventListener("tui:sync-changed", this._onSyncChanged)
    if (this._settleTimer) clearTimeout(this._settleTimer)
    if (this._scrambleInterval) clearInterval(this._scrambleInterval)
  }

  handleActivity() {
    if (this.stateValue === "disconnected") return
    this.applyState("syncing")
    if (this._settleTimer) clearTimeout(this._settleTimer)
    this._settleTimer = setTimeout(() => this.applyState("synced"), this.constructor.SETTLE_MS)
  }

  handleSyncChanged(event) {
    const state = event && event.detail && event.detail.state
    if (!state) return
    if (state === "disconnected") {
      if (this._settleTimer) clearTimeout(this._settleTimer)
      this.applyState("disconnected")
    } else if (state === "synced" && this.stateValue === "disconnected") {
      this.applyState("synced")
    }
  }

  applyState(s) {
    if (s === this.stateValue) return
    this.stateValue = s

    // Class flip drives color + shimmer animation immediately.
    this.element.classList.remove("is-synced", "is-syncing", "is-disconnected")
    this.element.classList.add(`is-${s}`)

    // Cancel any in-flight scramble before starting a new one.
    if (this._scrambleInterval) {
      clearInterval(this._scrambleInterval)
      this._scrambleInterval = null
    }
    this._scrambleInterval = scrambleWord(this.element, () => {
      this._scrambleInterval = null
    })
  }
}
