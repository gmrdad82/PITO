import { Controller } from "@hotwired/stimulus"

/**
 * @module controllers/tui_help_dialog
 *
 * @contract
 * Beta 4 — D9 (2026-05-22). Opens the Help dialog in response to three
 * canonical triggers:
 *
 *   - `?` keydown         — global direct shortcut (opens or closes the
 *                           dialog when no input surface has focus and no
 *                           modifier key is held).
 *   - `pito:leader:open_help` — fired by `tui-leader-menu` when the user
 *                               picks `SPACE ?` from the leader popup.
 *   - `pito:action:open_help` — canonical action-bus path (fired by
 *                               `tui-command-palette` when the user runs
 *                               `:help`, so leader + palette converge on
 *                               a single open path).
 *
 * All three open paths call `<dialog>.showModal()` on the element this
 * controller is mounted on. Esc + backdrop-click guard close are owned
 * by the underlying `tui-dialog` controller (mounted alongside via the
 * `Tui::DialogComponent` `extra_controllers:` slot).
 *
 * Idempotent: if the dialog is already `[open]`, the open call is a
 * no-op (avoids "InvalidStateError: already an open dialog" in browsers
 * that throw on re-entrant `showModal`).
 *
 * Gating for the `?` keydown path mirrors the other global keydown
 * controllers:
 *   * a form-entry surface (input / textarea / select /
 *     [contenteditable]) absorbs the keystroke so typing a `?` into a
 *     search field still works.
 *   * Ctrl / Meta / Alt modifiers bail (Shift is allowed because `?`
 *     itself requires Shift on most layouts).
 *
 * Replaces the legacy `tui-help-overlay` controller retired in D9.
 *
 * @testability
 * No JS unit tests in this project. The wiring is asserted at the
 * component layer (Tui::HelpDialogComponent spec verifies the
 * `data-controller` value includes `tui-help-dialog`).
 */
export default class extends Controller {
  connect() {
    this.boundKey    = this.handleKey.bind(this)
    this.boundOpen   = this.open.bind(this)
    document.addEventListener("keydown", this.boundKey)
    document.addEventListener("pito:leader:open_help", this.boundOpen)
    document.addEventListener("pito:action:open_help", this.boundOpen)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKey)
    document.removeEventListener("pito:leader:open_help", this.boundOpen)
    document.removeEventListener("pito:action:open_help", this.boundOpen)
  }

  handleKey(event) {
    if (event.target.matches("input, textarea, select, [contenteditable]")) return
    if (event.ctrlKey || event.metaKey || event.altKey) return

    if (event.key === "?") {
      event.preventDefault()
      this.toggle()
    }
  }

  toggle() {
    if (this.element.open) this.close()
    else this.open()
  }

  open() {
    if (typeof this.element.showModal !== "function") return
    if (this.element.open) return
    this.element.showModal()
  }

  close() {
    this.element.close()
  }
}
