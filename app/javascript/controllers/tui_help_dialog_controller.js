import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase D9 (2026-05-22). Stimulus controller for the TUI help
// dialog (`Tui::HelpDialogComponent`, mounted in
// `app/views/layouts/application.html.erb`). Listens for `?` at document
// level and toggles the `<dialog>` via the browser-native `showModal()` /
// `close()` API so the dialog lands in the top layer (above any pre-
// existing `<dialog>`).
//
// Backdrop-click guard + Esc dismissal are handled by the sibling
// `tui-dialog` controller mounted by `Tui::DialogComponent`. This
// controller only adds the `?` document-level keybind plus the toggle
// semantics (a second `?` from a help-induced workflow flips the surface
// off without a hand jump to Esc).
//
// Gating mirrors the other global keydown controllers
// (`flat_key_controller.js`, `leader_menu_controller.js`):
//   * a form-entry surface (input / textarea / select /
//     [contenteditable]) absorbs the keystroke so typing a `?` into a
//     search field still works.
//   * Ctrl / Meta / Alt modifiers bail (Shift is allowed because `?`
//     itself requires Shift on most layouts).
//
// Replaces the legacy `tui-help-overlay` controller retired in D9.
export default class extends Controller {
  connect() {
    this.boundHandler = this.handleKey.bind(this)
    document.addEventListener("keydown", this.boundHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandler)
  }

  handleKey(event) {
    if (event.target.matches("input, textarea, select, [contenteditable]")) return
    if (event.ctrlKey || event.metaKey || event.altKey) return

    if (event.key === "?") {
      this.toggle()
      event.preventDefault()
    }
  }

  toggle() {
    if (this.element.open) this.close()
    else this.open()
  }

  open() {
    this.element.showModal()
  }

  close() {
    this.element.close()
  }
}
