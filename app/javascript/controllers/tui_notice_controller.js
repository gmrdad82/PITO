import { Controller } from "@hotwired/stimulus"

/**
 * tui-notice — ephemeral centered notice slot in the TST.
 *
 * Phase 1D (2026-05-24) — created for the sync system end-to-end
 * rebuild. Pairs with `Tui::TstNoticeComponent`. Listens for
 * `tui:notice` document events and paints the message verbatim in
 * the slot for `durationValue` ms, then fades it out.
 *
 * ## Event contract
 *
 *   document.dispatchEvent(new CustomEvent("tui:notice", {
 *     detail: { message: "sync paused", severity: "info" }
 *   }))
 *
 *   message  : string — already-i18n'd display text (no client-side
 *              translation, the caller picks the resolved string).
 *   severity : "info" | "success" | "warn" | "danger" — sets the
 *              `data-severity` attribute on the host span for CSS
 *              styling. Defaults to "info" when omitted.
 *
 * ## Behavior
 *
 *   - On every event, the slot text is replaced and the `is-visible`
 *     class is added. The fade-out timer is reset on each event so a
 *     burst of notices ends up showing only the latest message for
 *     the full duration window.
 *   - When the timer fires, the `is-visible` class is removed and
 *     CSS transitions the slot to opacity 0. After the CSS transition
 *     completes the text is cleared so a stale message can't briefly
 *     re-appear.
 *
 * ## Targets
 *
 *   slot — inner <span> whose textContent is replaced with the message.
 *
 * ## Values
 *
 *   duration : Number (ms). Defaults to 2500. Time the notice stays
 *              visible before the fade-out begins.
 */
export default class extends Controller {
  static targets = ["slot"]
  static values = {
    duration: { type: Number, default: 2500 }
  }

  connect() {
    this._timer = null
    this._boundNotice = this.onNotice.bind(this)
    document.addEventListener("tui:notice", this._boundNotice)
  }

  disconnect() {
    document.removeEventListener("tui:notice", this._boundNotice)
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
  }

  onNotice(event) {
    const detail = (event && event.detail) || {}
    const message = typeof detail.message === "string" ? detail.message : ""
    const severity = typeof detail.severity === "string" ? detail.severity : "info"
    if (!message) return

    if (this.hasSlotTarget) {
      this.slotTarget.textContent = message
    }
    this.element.dataset.severity = severity
    this.element.classList.add("is-visible")

    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      this._timer = null
      this.element.classList.remove("is-visible")
      // Clear the text after a short delay so the CSS fade-out has time
      // to play out before the slot empties.
      setTimeout(() => {
        if (this.hasSlotTarget && !this.element.classList.contains("is-visible")) {
          this.slotTarget.textContent = ""
          this.element.dataset.severity = "none"
        }
      }, 250)
    }, this.durationValue)
  }
}
