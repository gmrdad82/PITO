// pito--autosuggest
//
// Float-above autocomplete palette for the chatbox textarea.
//
// Implements tasks ad+ae+af+ag:
//   ad — skeleton: connect, modeFor, onInput
//   ae — slash/hashtag palette (menu, filter, navigate, insert)
//   af — key coordination (handleKeydown intercepts BEFORE chat-form + home-transition)
//   ag — auth re-filter on Turbo auth-update
//
// DOM Contract (set by chatbox ERB — build against this exactly):
//   Controller:  pito--autosuggest  on  #pito-chatbox
//   Target field:    <textarea>  (data-pito--autosuggest-target="field")
//   Target catalog:  <script type="application/json">  (data-pito--autosuggest-target="catalog")
//   Target palette:  <div class="pito-autosuggest-palette hidden">  (data-pito--autosuggest-target="palette")
//
//   data-action order on the textarea (autosuggest FIRST so handleKeydown fires first):
//     keydown->pito--autosuggest#handleKeydown
//     keydown->pito--chat-form#handleKeydown
//     input->pito--autosuggest#onInput
//
// Key-suppression strategy (af):
//   When palette is open → preventDefault + stopImmediatePropagation so that
//   chat-form#handleKeydown (Enter=submit) and home-transition#interceptEnter
//   never see the event.  Stimulus fires data-action handlers for the same
//   event type in listed order on the same element; stopImmediatePropagation
//   prevents later handlers in that list from running.
//   When palette is closed → do NOT suppress; let everything pass through so
//   Enter submits, Shift+Tab/Shift+Space (chat-form) still work, plain Tab is
//   a no-op as documented in chat-form.
//
// Auth re-filter (ag):
//   The catalog <script> is rendered server-side with the correct auth-aware
//   slash list.  After /login or /logout the server replaces #pito-chatbox via
//   Turbo Stream → Stimulus calls connect() again on the new element and re-parses
//   the fresh catalog automatically.  As a belt-and-suspenders measure we also
//   listen for turbo:before-stream-render to re-read isAuthenticated() so that if
//   the palette happens to be open during the swap it collapses cleanly.

import { Controller } from "@hotwired/stimulus"
import { isAuthenticated } from "pito/auth"

export default class extends Controller {
  // ── Targets ────────────────────────────────────────────────────────────────
  static targets = ["field", "catalog", "palette"]

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  connect() {
    // ad: parse the embedded catalog JSON (auth-aware; rendered server-side)
    this._catalog      = this._parseCatalog()
    this._authenticated = isAuthenticated()

    // ad: initialise state
    this._open          = false
    this._items         = []   // [{label, description, insert}]
    this._selectedIndex = 0
    this._mode          = "none"

    // ag: belt-and-suspenders listener for Turbo stream renders that may swap
    // #pito-auth-gate (and therefore change auth state) without replacing the
    // chatbox.  If the chatbox IS replaced, connect() re-runs automatically.
    this._onTurboStream = () => {
      const wasAuthenticated = this._authenticated
      this._authenticated = isAuthenticated()
      if (wasAuthenticated !== this._authenticated) {
        // Re-parse catalog in case it was also replaced in the same stream.
        this._catalog = this._parseCatalog()
        if (this._open) this._refreshPalette()
      }
    }
    document.addEventListener("turbo:before-stream-render", this._onTurboStream)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this._onTurboStream)
  }

  // ── Public actions (wired via data-action on the textarea) ─────────────────

  // af: MUST be listed FIRST in data-action so it fires before chat-form#handleKeydown.
  handleKeydown(event) {
    if (this._open) {
      switch (event.key) {
        case "ArrowUp":
          event.preventDefault()
          event.stopImmediatePropagation()
          this._move(-1)
          return

        case "ArrowDown":
          event.preventDefault()
          event.stopImmediatePropagation()
          this._move(1)
          return

        case "Enter":
        case "Tab":
          event.preventDefault()
          event.stopImmediatePropagation()
          this._accept()
          return

        case "Escape":
          event.preventDefault()
          event.stopImmediatePropagation()
          this._close()
          return
      }
    }
    // Palette is closed (or key is not a palette key) → let the event pass through
    // so chat-form#handleKeydown and home-transition#interceptEnter can handle it.
  }

  // ad: recompute mode and refresh palette/ghost on every input event
  onInput(event) {
    const field  = this.fieldTarget
    const value  = field.value
    const cursor = field.selectionStart ?? value.length

    this._mode = this.modeFor(value, cursor)
    this._refreshPalette()
  }

  // ── ad: modeFor ────────────────────────────────────────────────────────────

  // Returns one of "slash" | "hashtag" | "free" | "none".
  // Looks at the text from the start of the field up to the cursor position.
  modeFor(value, cursor) {
    const before = value.slice(0, cursor)
    if (before.startsWith("/")) return "slash"
    if (before.startsWith("#")) return "hashtag"
    if (before.trim().length > 0) return "free"
    return "none"
  }

  // ── ae: palette rendering + filtering ─────────────────────────────────────

  _refreshPalette() {
    const field  = this.fieldTarget
    const value  = field.value
    const cursor = field.selectionStart ?? value.length

    if (this._mode === "slash") {
      this._items = this._buildSlashItems(value, cursor)
    } else if (this._mode === "hashtag") {
      this._items = this._buildHashtagItems(value, cursor)
    } else {
      // free / none → no slash/hashtag menu (ghost is a later task)
      this._items = []
    }

    if (this._items.length === 0) {
      this._close()
      return
    }

    // Clamp selectedIndex if the list shrank
    if (this._selectedIndex >= this._items.length) {
      this._selectedIndex = 0
    }

    this._renderRows()
    this._open = true
    this.paletteTarget.classList.remove("hidden")
  }

  // ae: build slash items by prefix-matching the typed partial after "/"
  _buildSlashItems(value, cursor) {
    // Extract the partial command name (text after "/" up to cursor, no spaces)
    const partial = value.slice(1, cursor).split(" ")[0].toLowerCase()

    return (this._catalog.slash || [])
      .filter(entry => entry.name.toLowerCase().startsWith(partial))
      .map(entry => ({
        label:       "/" + entry.name,
        description: entry.description || "",
        insert:      entry.insert,     // e.g. "/config " (with trailing space)
      }))
  }

  // ae: build hashtag items by prefix-matching the typed partial after "#"
  _buildHashtagItems(value, cursor) {
    const partial = value.slice(1, cursor).split(" ")[0].toLowerCase()

    return (this._catalog.hashtag || [])
      .filter(entry => entry.name.toLowerCase().startsWith(partial))
      .map(entry => ({
        label:       "#" + entry.name,
        description: entry.description || "",
        insert:      "#" + entry.insert, // insert already contains the verb; prefix # so it replaces correctly
      }))
  }

  // ae: render rows matching the server component's classes exactly
  // (pito-autosuggest-row, data-index, is-selected; label in 16ch column + dim description)
  _renderRows() {
    const palette = this.paletteTarget
    palette.innerHTML = ""

    this._items.forEach((item, i) => {
      const row = document.createElement("div")
      row.className  = "pito-autosuggest-row py-0.5 px-2.5"
      if (i === this._selectedIndex) row.classList.add("is-selected")
      row.dataset.index = i

      const labelEl = document.createElement("span")
      labelEl.className   = "text-fg inline-block"
      labelEl.style.width = "16ch"
      labelEl.textContent = item.label

      const descEl = document.createElement("span")
      descEl.className   = "text-fg-dim"
      descEl.textContent = item.description

      row.appendChild(labelEl)
      row.appendChild(descEl)

      // ae: mouse support — click a row to accept it
      row.addEventListener("mousedown", (e) => {
        // mousedown (not click) so we fire before the textarea blur
        e.preventDefault()
        this._selectedIndex = i
        this._accept()
      })

      palette.appendChild(row)
    })
  }

  // ── ae: navigation ─────────────────────────────────────────────────────────

  _move(delta) {
    if (!this._items.length) return
    this._selectedIndex = (this._selectedIndex + delta + this._items.length) % this._items.length
    this._renderRows()
  }

  // ae: accept the currently highlighted item
  _accept() {
    const item = this._items[this._selectedIndex]
    if (!item) { this._close(); return }

    this._insertToken(item.insert)
    this._close()
  }

  // ae: replace the active token (the prefix that triggered the palette) with insert
  _insertToken(insertText) {
    const field  = this.fieldTarget
    const value  = field.value
    const cursor = field.selectionStart ?? value.length
    const mode   = this._mode

    let tokenStart = 0
    if (mode === "slash" || mode === "hashtag") {
      // The token begins at position 0 (slash/hashtag always start the field for now).
      // Find the end of the current token = next whitespace or end.
      const afterTrigger = value.slice(1, cursor)
      const spaceIdx     = afterTrigger.indexOf(" ")
      const tokenEnd     = spaceIdx === -1 ? cursor : 1 + spaceIdx
      tokenStart         = 0

      field.value = insertText + value.slice(tokenEnd)
    } else {
      field.value = insertText + value.slice(cursor)
    }

    // Place cursor at end of inserted text
    const newPos = insertText.length
    field.selectionStart = field.selectionEnd = newPos

    // Notify other controllers (chat-form hiddenInput sync, etc.)
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.focus({ preventScroll: true })
  }

  // ── palette open/close helpers ─────────────────────────────────────────────

  _close() {
    this._open = false
    this.paletteTarget.classList.add("hidden")
    this.paletteTarget.innerHTML = ""
    this._items         = []
    this._selectedIndex = 0
    // Reset mode so next onInput recomputes cleanly
    this._mode = "none"
  }

  // ── ag: catalog parsing (called on connect + on auth change) ───────────────

  _parseCatalog() {
    try {
      return JSON.parse(this.catalogTarget.textContent)
    } catch (e) {
      console.warn("[pito--autosuggest] Failed to parse catalog JSON:", e)
      return { slash: [], hashtag: [], chat: [], vocabularies: {} }
    }
  }
}
