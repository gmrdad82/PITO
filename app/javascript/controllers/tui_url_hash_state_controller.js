import { Controller } from "@hotwired/stimulus"

/**
 * tui-url-hash-state — reusable URL hash persistence + restoration.
 *
 * Lets any consumer declare a `key=value` entry that lives in
 * `window.location.hash`, so refreshes preserve state without a
 * page reload. Generalizes the pattern from sortable_table_controller.
 *
 * Mount:
 *   <div data-controller="tui-url-hash-state"
 *        data-tui-url-hash-state-key-value="calendar-mode">
 *
 * API:
 *   - setValue(v)  → writes `key=v` into the hash (history.replaceState)
 *   - getValue()   → reads current `key=...` from the hash (String | null)
 *   - connect()    → reads hash; if this key exists, dispatches
 *                    `tui:url-hash-state-restored` on the element with
 *                    detail { key, value }
 *
 * Hash format: `k1=v1&k2=v2` — multiple keys coexist peacefully; each
 * controller instance owns exactly its declared key.
 *
 * Example hash: `#calendar-mode=schedule&filter-channel=gaming`
 *   - calendar-mode controller owns "calendar-mode"
 *   - a filter-chip controller owns "filter-channel"
 *
 * Consumer (e.g. calendar mode toggle) pattern:
 *   1. Mount this controller with key="calendar-mode" on the container.
 *   2. Listen for `tui:url-hash-state-restored` to re-apply saved mode.
 *   3. On toggle, call `this.urlHashStateController.setValue(newMode)`.
 *
 * Related: sortable_table_controller.js (owns its own hash key via table id;
 * migration to this controller is optional and deferred).
 */
export default class extends Controller {
  static values = { key: String }

  connect() {
    const restored = this.getValue()
    if (restored !== null) {
      this.dispatch("restored", {
        detail: { key: this.keyValue, value: restored },
        bubbles: true,
      })
    }
  }

  /**
   * setValue(v) — write `key=v` into the URL hash without a page reload.
   * Preserves all other keys already present in the hash.
   *
   * @param {string} v
   */
  setValue(v) {
    const params = this._parseHash()
    params.set(this.keyValue, String(v))
    this._writeHash(params)
  }

  /**
   * getValue() — read the current value for this key from the URL hash.
   *
   * @returns {string|null} the stored value, or null if absent
   */
  getValue() {
    const params = this._parseHash()
    return params.has(this.keyValue) ? params.get(this.keyValue) : null
  }

  /**
   * clearValue() — remove this key from the URL hash entirely.
   * Useful when returning to a default state that needs no URL entry.
   */
  clearValue() {
    const params = this._parseHash()
    params.delete(this.keyValue)
    this._writeHash(params)
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /**
   * _parseHash() — parse `window.location.hash` into a Map of key → value.
   * Strips the leading `#`. Ignores malformed pairs.
   *
   * @returns {Map<string, string>}
   */
  _parseHash() {
    const hash = window.location.hash.replace(/^#/, "")
    const params = new Map()
    if (!hash) return params
    hash.split("&").forEach(pair => {
      const eqIdx = pair.indexOf("=")
      if (eqIdx === -1) return
      const k = decodeURIComponent(pair.slice(0, eqIdx))
      const v = decodeURIComponent(pair.slice(eqIdx + 1))
      if (k) params.set(k, v)
    })
    return params
  }

  /**
   * _writeHash(map) — serialise a Map back into the URL hash via replaceState.
   * Preserves pathname + search. If the map is empty, removes the hash entirely.
   *
   * @param {Map<string, string>} map
   */
  _writeHash(map) {
    const base = `${window.location.pathname}${window.location.search}`
    if (map.size === 0) {
      history.replaceState(null, "", base)
      return
    }
    const hash = Array.from(map.entries())
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&")
    history.replaceState(null, "", `${base}#${hash}`)
  }
}
