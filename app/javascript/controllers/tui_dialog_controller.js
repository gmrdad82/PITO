import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase D9 (2026-05-22). Canonical Stimulus controller for
// `Tui::DialogComponent`. Provides the universal dismissal contract every
// dialog in pito honors:
//
//   * `[Esc]` is the single canonical dismiss path. The `<dialog>` element's
//     native Esc handling fires a `cancel` event before `close`; this
//     controller lets Esc through unchanged.
//   * Backdrop clicks DO NOT dismiss. A click on the `<dialog>` element
//     itself (vs. a descendant) lands when the user clicks the backdrop
//     region; `preventDefault` + `stopPropagation` at capture phase keep
//     the dialog open and stop the event reaching sibling controllers.
//   * `open()` / `close()` are exposed for callers that want to drive the
//     dialog from JS (e.g. command palette `:about` / `:help`, action bus
//     confirmation requests, keyboard-only mouse-guard alert).
//
// Composes cleanly with sibling controllers (e.g. `tui-confirmation-dialog`,
// `tui-help-dialog`) — Stimulus runs each controller independently, and the
// capture-phase click guard runs before bubble-phase click handlers.
export default class extends Controller {
  connect() {
    this.boundClickGuard = this.handleClick.bind(this)
    this.element.addEventListener("click", this.boundClickGuard, true)
  }

  disconnect() {
    this.element.removeEventListener("click", this.boundClickGuard, true)
  }

  handleClick(event) {
    // event.target === this.element ⇒ click landed on the dialog box itself
    // (the backdrop region, or the dialog padding outside the content). On
    // inner content the target is a descendant — let it pass through.
    if (event.target === this.element) {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  open() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    if (this.element.open) this.element.close()
  }
}
