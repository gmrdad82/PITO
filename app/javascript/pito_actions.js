/**
 * @module pito_actions
 *
 * @contract
 * Single entry point for user-triggerable actions per ADR 0018.
 * Every consumer (mouse click on a [reindex] button, `:reindex Meilisearch`
 * palette command, future leader menu, future MCP click) calls
 * `Pito.dispatchAction(name)`.
 *
 * Reads the action registry from `<meta name="pito-actions" content="JSON">`.
 *
 * If the action has `confirmation:`, dispatches the
 * `pito:action:confirm-requested` event the existing confirmation dialog
 * listens to. On confirm the dialog re-targets its form to the action's
 * `path` + submits Turbo-driven; the controller responds 204 no_content
 * and cable broadcasts handle the UI update.
 *
 * @testability
 * Behavioral contract above is the spec. No JS unit tests in this project
 * (no Capybara, no system specs). The backing Ruby surfaces
 * (`Pito::ActionRegistry`, `Pito::CableBroadcaster`, the
 * `Tui::ConfirmationDialogComponent`) carry spec coverage.
 */

// 2026-05-24 — client-side action whitelist. Actions in this map run
// entirely in JS (no POST, no path lookup). The leader menu / palette /
// any other dispatcher hands them off here.
const CLIENT_ACTIONS = {
  // `Space s` master switch — toggle the `pito.sync.app` localStorage
  // flag (single global master across every screen) and dispatch
  // `tui:sync-changed` so every panel + sub-panel sync VC anywhere
  // re-evaluates via the existing cascade path.
  //
  // 2026-05-24 (sync-rebuild) — master key renamed from `pito.sync.home`
  // to `pito.sync.app`. Architecture lock: ONE master flag covers
  // every screen (videos/games will share the same gate when their
  // sync VCs land). Per-panel-per-screen flags stay scoped
  // (`pito.sync.<screen>.<panel>`).
  //
  // After the flip the handler fires a `tui:notice` event so the TST
  // notice slot surfaces the visible "sync paused" / "sync resumed"
  // confirmation. Messages flow through i18n
  // (`tui.notices.sync_paused` / `tui.notices.sync_resumed`).
  // 2026-05-25 — explicit cascade. TST toggle walks every panel +
  // sub-panel sync VC target on the page, writes its localStorage flag
  // to the new uniform value, fires `tui:sync-changed` per target so
  // each VC re-paints from its own flag. No more master-lookup at
  // read time — write propagates explicitly.
  toggle_tst_sync() {
    const key = "pito.sync.app"
    const raw = localStorage.getItem(key)
    const currentlyEnabled = raw === "no" ? false : true
    const nextEnabled = !currentlyEnabled
    const value = nextEnabled ? "yes" : "no"

    localStorage.setItem(key, value)

    const targetEls = document.querySelectorAll('[data-tui-sync-indicator-target-value]')
    const targets = new Set()
    targetEls.forEach((el) => {
      const t = el.getAttribute("data-tui-sync-indicator-target-value")
      if (t) targets.add(t)
    })

    targets.forEach((t) => {
      localStorage.setItem(`pito.sync.${t}`, value)
      document.dispatchEvent(new CustomEvent("tui:sync-changed", {
        detail: { target: t, parentTarget: null, enabled: nextEnabled }
      }))
    })

    document.dispatchEvent(new CustomEvent("tui:sync-changed", {
      detail: { target: "app", parentTarget: null, enabled: nextEnabled }
    }))

    const message = readNoticeI18n(nextEnabled ? "sync_resumed" : "sync_paused")
    if (message) {
      document.dispatchEvent(new CustomEvent("tui:notice", {
        detail: { message, severity: "info" }
      }))
    }
  }
}

// Reads the resolved i18n string for a notice key out of the
// `<meta name="pito-notices" content="JSON">` payload emitted by the
// layout. Returns the string when present, or null when the meta is
// missing / the key is absent (caller decides whether to fire a
// fallback). Centralized here so every JS-side notice emitter shares
// one lookup contract.
function readNoticeI18n(key) {
  const meta = document.querySelector('meta[name="pito-notices"]')
  if (!meta) return null
  let map
  try { map = JSON.parse(meta.content) } catch (_) { return null }
  if (!map || typeof map !== "object") return null
  const value = map[key]
  return typeof value === "string" ? value : null
}

const PITO = {
  dispatchAction(name) {
    // 2026-05-24 — client-side action short-circuit. Avoids the
    // registry / POST roundtrip for actions defined entirely in JS.
    if (Object.prototype.hasOwnProperty.call(CLIENT_ACTIONS, name)) {
      CLIENT_ACTIONS[name]()
      return
    }
    const meta = document.querySelector('meta[name="pito-actions"]')
    if (!meta) throw new Error("Pito.dispatchAction: <meta name=pito-actions> missing")
    const registry = JSON.parse(meta.content)
    const action = registry[name]
    if (!action) throw new Error(`Pito.dispatchAction: unknown action ${name}`)

    if (action.confirmation) {
      this._openConfirmation(action)
    } else {
      this._submit(action)
    }
  },

  _openConfirmation(action) {
    // Hand off to whichever dialog controller listens for this event.
    // The `Tui::ConfirmationDialogComponent` instance reads `event.detail`
    // and re-targets its form before calling `showModal()`.
    document.dispatchEvent(new CustomEvent("pito:action:confirm-requested", {
      detail: action
    }))
  },

  _submit(action) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = action.path
    form.style.display = "none"

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    if (csrfMeta) {
      const csrf = document.createElement("input")
      csrf.type = "hidden"
      csrf.name = "authenticity_token"
      csrf.value = csrfMeta.content
      form.appendChild(csrf)
    }

    if (action.method && action.method !== "post") {
      const methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      methodInput.value = action.method
      form.appendChild(methodInput)
    }

    document.body.appendChild(form)
    form.requestSubmit()
  }
}

window.Pito = PITO
export default PITO
