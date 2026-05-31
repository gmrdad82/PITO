// Pito::ScrollbackController
//
// Auto-scrolls the scrollback container to the bottom when:
//   (a) the user submits a command (chat-form dispatches "pito:submitted"),
//   (b) a new event segment is appended by Turbo (MutationObserver).
//
// T21.2 — "Respect scrolled up": if the user has scrolled up more than
// SCROLL_LOCK_THRESHOLD px from the bottom, auto-scroll is suppressed until
// they scroll back down to the bottom (at which point the lock is released).
//
// Usage:
//   <div id="pito-scrollback" data-controller="pito--scrollback">

import { Controller } from "@hotwired/stimulus"

// How many px from the bottom the user must scroll before we stop auto-scrolling.
const SCROLL_LOCK_THRESHOLD = 80

export default class extends Controller {
  connect() {
    this.scrollLocked = false
    this.#scrollToBottom({ instant: true })
    this.#bindScroll()
    this.#bindMutation()
    this.#bindSubmit()
  }

  disconnect() {
    this.abort?.abort()
    this.mutationObserver?.disconnect()
  }

  // ── internals ──────────────────────────────────────────────────────────────

  // Scroll to the bottom of the container.
  // `instant` skips smooth behaviour for the initial page load.
  #scrollToBottom({ instant = false } = {}) {
    if (this.scrollLocked) return
    this.element.scrollTo({
      top: this.element.scrollHeight,
      behavior: instant ? "instant" : "smooth",
    })
  }

  // Track whether the user has manually scrolled up.
  #bindScroll() {
    this.abort = new AbortController()
    this.element.addEventListener("scroll", () => {
      const distanceFromBottom =
        this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
      this.scrollLocked = distanceFromBottom > SCROLL_LOCK_THRESHOLD
    }, { signal: this.abort.signal, passive: true })
  }

  // Watch for Turbo appending new children (broadcast events).
  #bindMutation() {
    this.mutationObserver = new MutationObserver(() => {
      this.#scrollToBottom()
    })
    this.mutationObserver.observe(this.element, { childList: true })
  }

  // Listen for the form submission event dispatched by chat-form.
  // On submit, always scroll regardless of lock (the user just sent something).
  #bindSubmit() {
    document.addEventListener("pito:submitted", () => {
      this.scrollLocked = false
      this.#scrollToBottom()
    }, { signal: this.abort.signal })
  }
}
