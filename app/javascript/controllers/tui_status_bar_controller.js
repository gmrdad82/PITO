import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Beta 4 — Phase F1 Lane C. Live data wiring for
// `Tui::TopStatusBarComponent` (Lane B). Subscribes to the
// `StatusBarChannel` (Lane A — broadcasting `pito:status_bar`) and
// fans out kind-specific custom DOM events to child Stimulus controllers
// (one per ViewComponent slot: SyncIndicator, SidekiqStats, DateTime,
// etc.). The parent owns the cable subscription + breadcrumb + local
// wall-clock; every other slot is painted by its own child controller
// listening for the kind-specific event.
//
// 2026-05-22 (registry refactor) — the previous `switch (kind)` block
// was replaced by a frozen dictionary at module top (`KIND_HANDLERS`).
// Adding a new cable kind = one entry in the map. The same dispatch
// also fires a generic `tui:cable-activity` event on every received
// message so activity-aware listeners (e.g. the sync indicator pulse)
// can react without registering for each individual kind.
//
// 2026-05-22 (Wave 2D cleanup) — orphaned breadcrumb DOM-construction
// removed. The `tui-breadcrumb` controller (paired with the canonical
// `tui-transition` outlet) is now the sole owner of the `.sb-section`
// span. The previous in-controller `renderSectionBreadcrumb` + the
// `tui:panel-focus-changed` listener used to build `.sb-section__panel`
// / `.sb-section__sub-panel` / `.sb-section__sub-panel-paren` spans was
// deleted — those classes are no longer rendered anywhere in the tree.
//
// Targets:
//   root — the `.sb-bar` host. (Section / clock targets were removed
//   alongside the orphan; the children own their own DOM now.)
//
// Payload envelope follows ADR 0017:
//
//   { kind: "<state>", payload: { ... }, ts: "<iso-8601>" }
//
// Canonical kinds (FB-test-infra 2026-05-22):
//
//   sync          → fans out `tui:sync-changed`
//   sidekiq       → fans out `tui:sidekiq-changed`
//   notifications → fans out `tui:notifications-changed`
//   data          → alias of `sidekiq` (legacy Sidekiq middleware envelope)
//
// Legacy long-running-job kinds (idle / indeterminate / progress /
// complete / error) are registered without a kind-specific event —
// they still fire the generic `tui:cable-activity` event so any future
// activity-aware listener can pick them up.

// Cable-kind routing registry. Adding a new cable kind = one entry.
// Each entry declares:
//   - event: the document-level CustomEvent name fanned out for VCs to listen to
//   - payloadKeys: array of expected payload field names (for dev-time validation)
//   - alias: optional — when set, this kind is an alias of the named canonical kind
//
// EVERY received message — regardless of kind — also fires the generic
// `tui:cable-activity` event for activity-aware VCs (e.g. sync indicator).
export const KIND_HANDLERS = Object.freeze({
  sync:          { event: "tui:sync-changed",          payloadKeys: ["state", "target"] },
  sidekiq:       { event: "tui:sidekiq-changed",       payloadKeys: ["busy", "enqueued", "retry"] },
  notifications: { event: "tui:notifications-changed", payloadKeys: ["future_count"] },
  data:          { alias: "sidekiq" },  // legacy Sidekiq middleware kind
  // Legacy long-running-job kinds — fire activity event only, no specific listener:
  idle:          { event: null, payloadKeys: [] },
  indeterminate: { event: null, payloadKeys: [] },
  progress:      { event: null, payloadKeys: [] },
  complete:      { event: null, payloadKeys: [] },
  error:         { event: null, payloadKeys: [] }
})

export const ACTIVITY_EVENT = "tui:cable-activity"

export default class extends Controller {
  static targets = [
    "root"
  ]

  // Re-export the registry on the controller class so specs / external
  // consumers can lock the shape without importing the module directly.
  static KIND_HANDLERS = KIND_HANDLERS
  static ACTIVITY_EVENT = ACTIVITY_EVENT

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "StatusBarChannel" },
      {
        connected: () => this.onConnected(),
        disconnected: () => this.onDisconnected(),
        received: (data) => this.received(data)
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }
  }

  // ---------- Cable payload funnel (registry-driven) ----------

  // 2026-05-22 — Map-driven dispatch. Every received message fires
  // `tui:cable-activity` first (so activity-aware listeners pulse on
  // any traffic), then resolves the `kind` to its registry entry and
  // fans out the kind-specific event if defined. Aliases are resolved
  // one hop (no recursion needed).
  received(data) {
    const { kind, payload } = data || {}

    // Always fire the generic activity event first — for activity-aware listeners.
    document.dispatchEvent(new CustomEvent(ACTIVITY_EVENT, {
      detail: { kind, payload, ts: data?.ts },
      bubbles: false
    }))

    // Resolve aliases (one hop only).
    let handler = KIND_HANDLERS[kind]
    if (handler && handler.alias) handler = KIND_HANDLERS[handler.alias]
    if (!handler) {
      console.warn(`[tui-status-bar] unknown cable kind: ${kind}`)
      return
    }

    // Fan-out the kind-specific event if defined.
    if (handler.event) {
      document.dispatchEvent(new CustomEvent(handler.event, {
        detail: payload || {},
        bubbles: false
      }))
    }
  }

  // ---------- Cable lifecycle callbacks ----------
  //
  // Cable connect / disconnect are signaled out via the same custom
  // event mechanism the registry uses — the SyncIndicator child
  // controller listens for explicit `disconnected` state via
  // `tui:sync-changed` so the dot can flip red without needing a
  // dedicated event channel for cable lifecycle.

  onConnected() {
    // Cable established — re-paint as synced.
    document.dispatchEvent(new CustomEvent("tui:sync-changed", {
      detail: { state: "synced" },
      bubbles: false
    }))
  }

  onDisconnected() {
    // Cable dropped — surface the red ✗ disconnected indicator per
    // ADR 0017's error-handling section.
    document.dispatchEvent(new CustomEvent("tui:sync-changed", {
      detail: { state: "disconnected" },
      bubbles: false
    }))
  }
}
