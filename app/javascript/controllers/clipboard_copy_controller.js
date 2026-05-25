import { Controller } from "@hotwired/stimulus"

// clipboard-copy — Code-block component with [ copy ] button.
//
// Reads textContent from the source target, writes to clipboard via the
// async navigator.clipboard API (NOT alert/confirm/prompt — those are
// banned by the Pito hard rules), then either:
//
//   a) dispatches a top-right toast notice (authenticated surface, where
//      `.toast-container` exists in the DOM), OR
//   b) briefly swaps the button's `.bl` label to the configured
//      `toastMessageValue` and reverts after 1.5 s (unauthenticated
//      surface, e.g. the auth dialog, where no toast container is present).
//
// The fallback (b) guarantees feedback even before the user is signed in.
//
// Values:
//   toastMessage [String] — label shown on copy. Defaults to "paste it in
//     your terminal." Used as the toast message (a) or the inline label (b).
//
// Targets:
//   source — the element whose textContent is copied.
//
// Usage (ERB):
//   data-controller="clipboard-copy"
//   data-clipboard-copy-toast-message-value="copied!"
//   data-clipboard-copy-target="source" on the <code> element
//   data-action="click->clipboard-copy#copy" on the button
//
// Z3-redesign (2026-05-25) — added inline label-swap fallback for the auth
// overlay where no toast container is available.
export default class extends Controller {
  static targets = ["source"]
  static values = {
    toastMessage: { type: String, default: "paste it in your terminal." }
  }

  copy(event) {
    event.preventDefault()
    const text = this.sourceTarget.textContent.trim()
    navigator.clipboard.writeText(text).then(() => {
      const container = document.querySelector(".toast-container")
      if (container) {
        this._flashToast(this.toastMessageValue)
      } else {
        this._flashInline(event.currentTarget)
      }
    })
  }

  // Inject a transient toast into `.toast-container` (authenticated surface).
  _flashToast(message) {
    const container = document.querySelector(".toast-container")
    if (!container) return
    const toast = document.createElement("div")
    toast.className = "toast toast-notice"
    toast.textContent = message
    toast.setAttribute("data-controller", "toast")
    container.appendChild(toast)
  }

  // Swap the button's `.bl` text label briefly, then revert (unauthenticated surface).
  _flashInline(btn) {
    if (!btn) return
    const bl = btn.querySelector(".bl")
    if (!bl) return
    const original = bl.textContent
    bl.textContent = this.toastMessageValue
    setTimeout(() => { bl.textContent = original }, 1500)
  }
}
