// pito--logout
//
// Attached to the LogoutComponent. On connect, runs a reverse home transition:
//   scrollback fades out → chatbox narrows + rises to center → Turbo.visit("/")
//
// Mirrors the timing of home_transition_controller in reverse.

import { Controller } from "@hotwired/stimulus"

const FADE_MS   = 220
const RISE_MS   = 240
const SHRINK_MS = 380

export default class extends Controller {
  connect() {
    this.#runReverseAnimation().then(() => {
      Turbo.visit("/")
    })
  }

  async #runReverseAnimation() {
    const scrollback = document.getElementById("pito-scrollback")
    const bottomPanel = this.element.closest("[style*='padding']") ||
                        this.element.closest("div[style]")?.parentElement
    const chatboxWrapper = document.querySelector("form.chatbox-form")?.closest("[style]") ||
                           document.querySelector("form.chatbox-form")?.parentElement

    // Find the bottom panel (the element wrapping form + chrome below scrollback).
    const form = document.querySelector("form.chatbox-form")
    const chatboxArea = form?.parentElement

    // Step 1: fade out scrollback.
    if (scrollback) {
      scrollback.style.transition = `opacity ${FADE_MS}ms ease`
      scrollback.style.opacity    = "0"
      scrollback.style.pointerEvents = "none"
    }
    await this.#wait(FADE_MS)

    if (!chatboxArea) {
      await this.#wait(RISE_MS + SHRINK_MS)
      return
    }

    // Step 2: capture current chatbox position and fix it.
    const rect = chatboxArea.getBoundingClientRect()
    chatboxArea.style.position  = "fixed"
    chatboxArea.style.top       = `${rect.top}px`
    chatboxArea.style.left      = `${rect.left}px`
    chatboxArea.style.width     = `${rect.width}px`
    chatboxArea.style.height    = `${rect.height}px`
    chatboxArea.style.margin    = "0"
    chatboxArea.style.zIndex    = "100"
    chatboxArea.style.transition = "none"
    chatboxArea.getBoundingClientRect()

    // Step 3: shrink width back toward ~600px centered.
    const targetWidth  = Math.min(600, window.innerWidth - 64)
    const targetLeft   = (window.innerWidth - targetWidth) / 2
    chatboxArea.style.transition = `width ${SHRINK_MS}ms cubic-bezier(0,0,0.6,1), left ${SHRINK_MS}ms cubic-bezier(0,0,0.6,1)`
    chatboxArea.style.width = `${targetWidth}px`
    chatboxArea.style.left  = `${targetLeft}px`
    await this.#wait(SHRINK_MS)

    // Step 4: rise to vertical center.
    const targetTop = (window.innerHeight - rect.height) / 2
    chatboxArea.style.transition = `top ${RISE_MS}ms cubic-bezier(0,0,0.6,1)`
    chatboxArea.style.top = `${targetTop}px`
    await this.#wait(RISE_MS)
  }

  #wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}
