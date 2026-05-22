import { Controller } from "@hotwired/stimulus"

/**
 * tui-size-guard — enforces minimum window dimensions.
 *
 * When window.innerWidth < MIN_WIDTH or window.innerHeight < MIN_HEIGHT,
 * displays the Tui::SizeGuardDialogComponent via showModal(). Auto-closes
 * when the window meets the minimum on a resize event. [Esc] dismisses
 * locally but the controller re-shows on the next resize check if the
 * viewport is still too small, so a sub-minimum window cannot escape
 * the guard.
 *
 * Min values locked at 2026-05-22 per docs/design.md § Layout:
 *   width  = 1280px (half of a 2560-wide 1440p display)
 *   height =  800px
 *
 * Pattern parity with the keyboard-only mouse guard
 * (tui_alert_dialog_controller / keyboard_only_controller): a global
 * input-class trigger that surfaces a Tui::AlertDialogComponent-style
 * message-only dialog.
 *
 * Mounted on the dialog element itself (NOT on <body>) so
 * this.element is the <dialog> we call showModal() / close() on.
 */
export default class extends Controller {
  static MIN_WIDTH = 1280
  static MIN_HEIGHT = 800
  static DEBOUNCE_MS = 80

  connect() {
    this._boundCheck = this.requestCheck.bind(this)
    this._debounceTimer = null
    window.addEventListener("resize", this._boundCheck)
    this.requestCheck()
  }

  disconnect() {
    window.removeEventListener("resize", this._boundCheck)
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
  }

  requestCheck() {
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => {
      this._debounceTimer = null
      this.check()
    }, this.constructor.DEBOUNCE_MS)
  }

  check() {
    const tooSmall = window.innerWidth < this.constructor.MIN_WIDTH ||
                     window.innerHeight < this.constructor.MIN_HEIGHT
    if (!this.element || typeof this.element.showModal !== "function") return
    if (tooSmall) {
      if (!this.element.open) this.element.showModal()
    } else {
      if (this.element.open) this.element.close()
    }
  }
}
