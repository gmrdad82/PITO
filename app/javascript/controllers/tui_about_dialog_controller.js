import { Controller } from "@hotwired/stimulus"

/**
 * @module controllers/tui_about_dialog
 *
 * @contract
 * Beta 4 — FB-ITEM-3 (2026-05-22). Opens the About dialog in response
 * to two canonical triggers:
 *
 *   - `pito:leader:open_about`  — fired by `tui-leader-menu` when the
 *                                  user picks `SPACE a` from the leader
 *                                  popup.
 *   - `pito:action:open_about`  — canonical action-bus path (fired by
 *                                  `tui-command-palette` when the user
 *                                  runs `:about`, so leader + palette
 *                                  converge on a single open path).
 *
 * Both handlers call `<dialog>.showModal()` on the element this
 * controller is mounted on. Esc + backdrop-click guard close are owned
 * by the underlying `tui-dialog` controller (mounted alongside via the
 * `Tui::DialogComponent` `extra_controllers:` slot).
 *
 * Idempotent: if the dialog is already `[open]`, the open call is a
 * no-op (avoids "InvalidStateError: already an open dialog" in browsers
 * that throw on re-entrant `showModal`).
 *
 * @testability
 * No JS unit tests in this project. The wiring is asserted at the
 * component layer (Tui::AboutDialogComponent spec verifies the
 * `data-controller` value includes `tui-about-dialog`).
 */
export default class extends Controller {
  connect() {
    this.boundOpen = this.open.bind(this)
    document.addEventListener("pito:leader:open_about", this.boundOpen)
    document.addEventListener("pito:action:open_about", this.boundOpen)
  }

  disconnect() {
    document.removeEventListener("pito:leader:open_about", this.boundOpen)
    document.removeEventListener("pito:action:open_about", this.boundOpen)
  }

  open() {
    if (typeof this.element.showModal !== "function") return
    if (this.element.open) return
    this.element.showModal()
  }
}
