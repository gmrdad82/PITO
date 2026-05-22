import { Controller } from "@hotwired/stimulus"

/**
 * tui-sync-indicator — thin delegator for Tui::SyncIndicatorComponent.
 *
 * Phase 2A (2026-05-22) — glyph-free, word-only. All visual animation
 * (scramble-settle, color-crossfade, shimmer) is delegated to the
 * colocated tui-transition outlet via setValue / setColor / setShimmer.
 * This controller's only job is event translation: cable lifecycle +
 * activity events on document → setState calls on the outlet.
 *
 * State model (2026-05-22 revision — busy-aware, no momentary pulse):
 *
 *   The sync indicator reflects ACTUAL ongoing work, not transient
 *   cable noise. The state is derived from the cable payload, NOT
 *   from the mere fact of receiving a broadcast.
 *
 *   Sidekiq stats (kind="sidekiq" or "data" alias):
 *     - busy > 0 OR enqueued > 0 OR retry > 0  →  setSyncing (sticky)
 *     - all zeros                              →  setSynced
 *
 *   tui:sync-changed (explicit state from cable lifecycle):
 *     detail.state ∈ { "synced" | "syncing" | "disconnected" }
 *     - disconnected → setDisconnected (overrides Sidekiq-derived state)
 *     - synced / syncing → respective setter
 *
 *   Other cable kinds (notifications, idle, indeterminate, progress,
 *   complete, error) are NOT (yet) wired to drive sync state. They fire
 *   tui:cable-activity but the sync controller ignores them. The current
 *   sync state is preserved across these events.
 *
 *   Rationale: the user-locked behavior is "when Sidekiq has work, sync
 *   is syncing; when Sidekiq is quiet, sync is synced". A timed pulse
 *   was flashing the indicator on every broadcast regardless of payload
 *   — including the welcome broadcast on page reload — which read as
 *   constant churn. Stats-derived state cleanly tracks real work.
 *
 * Canonical color lock (matches Tui::SyncIndicatorComponent#color_for):
 *   synced       → "muted"   // idle / calm
 *   syncing      → "accent"  // active, paired with shimmer
 *   disconnected → "danger"  // cable lifecycle error
 *
 * Sequencing rule (shimmer ↔ scramble, never overlap):
 *
 *   forward (synced → syncing):
 *     1. _shimmerOnSettle = true    // arm deferred shimmer-on
 *     2. setShimmer(false)          // clear stale shimmer
 *     3. setColor("accent")
 *     4. setValue(word)             // scramble starts
 *     5. on tui-transition:settled  // flag still true → setShimmer(true)
 *
 *   reverse (anything → synced / disconnected):
 *     1. _shimmerOnSettle = false   // disarm BEFORE scramble starts
 *     2. setShimmer(false)          // shimmer off FIRST
 *     3. setColor("muted" | "danger")
 *     4. setValue(word)             // scramble back; settled fires but flag is off
 *
 * Idempotency: each setter checks the current outlet value. If already
 * in the target state, the methods short-circuit — no re-color, no
 * re-value, no scramble trigger. Multiple Sidekiq broadcasts at the same
 * state (e.g. 5 lifecycle ticks during a single long-running job) leave
 * the visible state stable.
 *
 * Settled listener strategy: ONE permanent listener (`_boundSettled`)
 * attached to the outlet element on first attach. Gated by the
 * `_shimmerOnSettle` boolean. Avoids stale `{ once: true }` arrow
 * listeners firing during the LATER reverse-scramble.
 *
 * Word labels come from data-* values seeded by the VC (sourced from
 * `config/locales/tui/en.yml` `tui.tst.sync.*`) so this JS layer never
 * inlines English strings.
 */
export default class extends Controller {
  static outlets = ["tui-transition"]
  static values = {
    synced: String,
    syncing: String,
    disconnected: String
  }

  // Debounce-off cool-down. busy>0 broadcasts flip to syncing immediately
  // (no cool-down). busy=0 broadcasts arm a COOL_DOWN_MS timer; if another
  // busy>0 arrives during cool-down, the timer is cancelled and sync
  // stays in syncing. After COOL_DOWN_MS of all-zero broadcasts → setSynced.
  // Bridges rapid Sidekiq job cycles (small back-to-back jobs that pulse
  // busy=1/busy=0 in tight succession) without visible flicker.
  static COOL_DOWN_MS = 1000

  connect() {
    this._shimmerOnSettle = false
    this._settledAttachedTo = null
    this._coolDownTimer = null
    this._boundExplicit = this.onExplicitState.bind(this)
    this._boundActivity = this.onActivity.bind(this)
    this._boundSettled = this.onTransitionSettled.bind(this)
    document.addEventListener("tui:sync-changed", this._boundExplicit)
    document.addEventListener("tui:cable-activity", this._boundActivity)
  }

  disconnect() {
    document.removeEventListener("tui:sync-changed", this._boundExplicit)
    document.removeEventListener("tui:cable-activity", this._boundActivity)
    if (this._settledAttachedTo) {
      this._settledAttachedTo.removeEventListener("tui-transition:settled", this._boundSettled)
      this._settledAttachedTo = null
    }
    if (this._coolDownTimer) {
      clearTimeout(this._coolDownTimer)
      this._coolDownTimer = null
    }
  }

  // ─── event handlers ───────────────────────────────────────────────
  onExplicitState(event) {
    const state = event?.detail?.state
    if (!state) return
    if (state === "disconnected") {
      this.setDisconnected()
    } else if (state === "syncing") {
      this.setSyncing()
    } else if (state === "synced") {
      this.setSynced()
    }
  }

  // Sidekiq-aware activity handler. Only Sidekiq stats currently drive
  // the syncing/synced state. Other kinds are ignored here (they still
  // fire their own kind-specific events for kind-targeted VCs).
  //
  // Debounce-off: busy>0 → setSyncing immediately + cancel any pending
  // cool-down. busy=0 → arm a COOL_DOWN_MS timer; only setSynced after
  // the timer expires with no intervening busy>0.
  onActivity(event) {
    const detail = event?.detail || {}
    const { kind, payload } = detail
    if (kind !== "sidekiq" && kind !== "data") return  // not a sync-driving kind
    if (this.sidekiqActive(payload)) {
      if (this._coolDownTimer) {
        clearTimeout(this._coolDownTimer)
        this._coolDownTimer = null
      }
      this.setSyncing()
    } else {
      if (this._coolDownTimer) clearTimeout(this._coolDownTimer)
      this._coolDownTimer = setTimeout(() => {
        this.setSynced()
        this._coolDownTimer = null
      }, this.constructor.COOL_DOWN_MS)
    }
  }

  onTransitionSettled() {
    if (this._shimmerOnSettle && this.hasTuiTransitionOutlet) {
      this.tuiTransitionOutlet.setShimmer(true)
    }
  }

  // ─── delegation to tui-transition outlet ──────────────────────────
  setSyncing() {
    const c = this.transitionController()
    if (!c) return
    this.ensureSettledListenerAttached()
    this._shimmerOnSettle = true
    if (this.currentValue() === this.wordFor("syncing")) return  // idempotent
    c.setShimmer(false)
    c.setColor("accent")
    c.setValue(this.wordFor("syncing"))
  }

  setSynced() {
    const c = this.transitionController()
    if (!c) return
    this._shimmerOnSettle = false
    if (this.currentValue() === this.wordFor("synced")) {
      c.setShimmer(false)
      return
    }
    c.setShimmer(false)
    c.setColor("muted")
    c.setValue(this.wordFor("synced"))
  }

  setDisconnected() {
    const c = this.transitionController()
    if (!c) return
    this._shimmerOnSettle = false
    if (this.currentValue() === this.wordFor("disconnected")) {
      c.setShimmer(false)
      return
    }
    c.setShimmer(false)
    c.setColor("danger")
    c.setValue(this.wordFor("disconnected"))
  }

  // ─── helpers ──────────────────────────────────────────────────────
  sidekiqActive(payload) {
    if (!payload || typeof payload !== "object") return false
    const b = parseInt(payload.busy || 0, 10) || 0
    const e = parseInt(payload.enqueued || 0, 10) || 0
    const r = parseInt(payload.retry || 0, 10) || 0
    return b > 0 || e > 0 || r > 0
  }

  transitionController() {
    if (this.hasTuiTransitionOutlet) return this.tuiTransitionOutlet
    return null
  }

  ensureSettledListenerAttached() {
    if (!this.hasTuiTransitionOutlet) return
    const target = this.tuiTransitionOutlet.element
    if (this._settledAttachedTo === target) return
    if (this._settledAttachedTo) {
      this._settledAttachedTo.removeEventListener("tui-transition:settled", this._boundSettled)
    }
    target.addEventListener("tui-transition:settled", this._boundSettled)
    this._settledAttachedTo = target
  }

  currentValue() {
    if (!this.hasTuiTransitionOutlet) return null
    return this.tuiTransitionOutlet.valueValue
  }

  wordFor(stateName) {
    if (stateName === "synced")       return this.syncedValue
    if (stateName === "syncing")      return this.syncingValue
    if (stateName === "disconnected") return this.disconnectedValue
    return stateName
  }
}
