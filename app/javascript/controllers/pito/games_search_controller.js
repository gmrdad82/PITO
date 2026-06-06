// pito--games-search
//
// Mounted on the `[data-controller="pito--games-search"]` element that the
// IGDB import sidebar injects into #pito-sidebar.
//
// BEHAVIOUR
//   - On connect(): if prefill is non-empty, populate the input and fire an
//     immediate search (no debounce delay for the pre-filled query).
//   - On input events: debounce 250ms + AbortController to cancel stale requests.
//   - Renders results as .pito-igdb-row elements inside the results target.
//   - ↑ / ↓ moves highlight through rows.
//   - Enter on a highlighted row sends POST /games/import with the igdb_id +
//     title + conversation UUID.  Shows progress feedback in the status line.
//   - Escape: handled by pito--resume's capture-phase listener (clears sidebar).
//
// DOM contract (set by GamesImport::Component ERB):
//   Controller: pito--games-search  on  .flex.flex-col wrapper
//   Values:     conversation-uuid (String), prefill (String)
//   Targets:    input   — <input type="text">
//               status  — <p> for status text
//               results — <div> container for result rows
//
// Auto-registered via eagerLoadControllersFrom.

import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS   = 250
const HIGHLIGHT_CLS = "pito-resume-highlight"

export default class extends Controller {
  static targets = ["input", "status", "results"]
  static values  = {
    conversationUuid: String,
    prefill:          { type: String, default: "" },
  }

  connect() {
    this._timer       = null
    this._abort       = null
    this._requestId   = 0
    this._highlightIdx = -1

    // Listen for keydown on document so ↑/↓/Enter work even when the
    // input doesn't have focus (e.g. after clicking a row).
    this._onKey = this.#onKey.bind(this)
    document.addEventListener("keydown", this._onKey)

    // Wire input → debounced search
    this.inputTarget.addEventListener("input", this.#onInput.bind(this))

    // Prefill: trigger an immediate search if there's a preset query.
    const pre = this.prefillValue.trim()
    if (pre.length > 0) {
      this.inputTarget.value = pre
      this.#doSearch(pre)
    }

    this.inputTarget.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKey)
    this.#cancelPending()
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #onInput() {
    const q = this.inputTarget.value.trim()
    this.#cancelPending()

    if (q.length === 0) {
      this.#setStatus("")
      this.resultsTarget.innerHTML = ""
      this._highlightIdx = -1
      return
    }

    this._timer = setTimeout(() => {
      this._timer = null
      this.#doSearch(q)
    }, DEBOUNCE_MS)
  }

  async #doSearch(query) {
    this.#setStatus(this.#t("searching"))
    this.resultsTarget.innerHTML = ""
    this._highlightIdx = -1

    const myId = ++this._requestId
    const abort = new AbortController()
    this._abort = abort

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const resp = await fetch("/games/search", {
        method:  "POST",
        signal:  abort.signal,
        headers: {
          "Content-Type": "application/json",
          "Accept":       "application/json",
          ...(csrf ? { "X-CSRF-Token": csrf } : {}),
        },
        body: JSON.stringify({ query }),
      })

      if (myId !== this._requestId) return

      if (!resp.ok) {
        this.#setStatus(this.#t("error"))
        return
      }

      const data = await resp.json()
      if (myId !== this._requestId) return

      if (data.error) {
        this.#setStatus(this.#t("error"))
        return
      }

      const hits = data.hits || []
      if (hits.length === 0) {
        this.#setStatus(this.#t("no_results"))
        return
      }

      this.#setStatus("")
      this.#renderResults(hits, data.library_ids || [])

      // Highlight first row automatically.
      this._highlightIdx = 0
      this.#paintHighlight()
    } catch (err) {
      if (err.name !== "AbortError" && myId === this._requestId) {
        this.#setStatus(this.#t("error"))
      }
    }
  }

  #renderResults(hits, libraryIds) {
    const container = this.resultsTarget
    container.innerHTML = ""

    hits.forEach((hit) => {
      const igdbId   = hit.id ?? hit["id"]
      const title    = hit.name ?? hit["name"] ?? ""
      const inLib    = libraryIds.includes(igdbId)
      const coverUrl = hit.cover?.url ?? hit["cover"]?.["url"] ?? null

      const row = document.createElement("div")
      row.className     = "pito-igdb-row flex gap-2 items-center py-1 px-2 rounded cursor-pointer hover:bg-bg-hover"
      row.dataset.igdbId = String(igdbId)
      row.dataset.title  = title

      // Cover thumbnail
      if (coverUrl) {
        const img = document.createElement("img")
        // Replace IGDB thumbnail size token with t_thumb (90×128 ~)
        img.src    = coverUrl.replace("t_thumb", "t_thumb")
        img.alt    = title
        img.width  = 30
        img.height = 40
        img.className = "object-cover shrink-0 rounded-sm"
        row.appendChild(img)
      } else {
        const ph = document.createElement("div")
        ph.className = "w-[30px] h-[40px] shrink-0 rounded-sm bg-bg-hover"
        row.appendChild(ph)
      }

      // Title + in-library badge
      const info = document.createElement("div")
      info.className = "flex flex-col min-w-0"

      const titleEl = document.createElement("span")
      titleEl.className   = "text-fg truncate text-sm"
      titleEl.textContent = title
      info.appendChild(titleEl)

      if (inLib) {
        const badge = document.createElement("span")
        badge.className   = "text-xs text-accent"
        badge.textContent = this.#t("in_library") + " " + this.#t("in_library_hint")
        info.appendChild(badge)
      }

      row.appendChild(info)

      // Click to select
      row.addEventListener("click", () => {
        const rows = this.#rows()
        this._highlightIdx = rows.indexOf(row)
        this.#paintHighlight()
        this.#selectHighlighted()
      })

      container.appendChild(row)
    })
  }

  #onKey(e) {
    const rows = this.#rows()

    if (e.key === "ArrowDown") {
      e.preventDefault()
      if (this._highlightIdx < rows.length - 1) {
        this._highlightIdx++
        this.#paintHighlight()
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      if (this._highlightIdx > 0) {
        this._highlightIdx--
        this.#paintHighlight()
      }
    } else if (e.key === "Enter") {
      // Only intercept if we have a highlighted row; otherwise let the
      // chatbox form submit normally.
      if (rows.length > 0 && this._highlightIdx >= 0) {
        e.preventDefault()
        this.#selectHighlighted()
      }
    }
  }

  #selectHighlighted() {
    const rows = this.#rows()
    const row  = rows[this._highlightIdx]
    if (!row) return

    const igdbId = row.dataset.igdbId
    const title  = row.dataset.title
    if (!igdbId) return

    this.#importGame(igdbId, title)
  }

  async #importGame(igdbId, title) {
    // Clear sidebar immediately so the user knows selection was registered.
    const sidebar = document.getElementById("pito-sidebar")
    if (sidebar) sidebar.innerHTML = ""

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const uuid = this.conversationUuidValue

    try {
      await fetch("/games/import", {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept":       "application/json",
          ...(csrf ? { "X-CSRF-Token": csrf } : {}),
        },
        body: JSON.stringify({ igdb_id: igdbId, title, uuid }),
      })
      // The job streams progress + messages over ActionCable — no need to handle
      // the response body here (the job always returns 204 on success).
    } catch (_err) {
      // Network failure: swallow — user will notice the lack of progress events.
    }
  }

  #rows() {
    return Array.from(this.resultsTarget.querySelectorAll(".pito-igdb-row"))
  }

  #paintHighlight() {
    this.#rows().forEach((r, i) => r.classList.toggle(HIGHLIGHT_CLS, i === this._highlightIdx))
    const focused = this.#rows()[this._highlightIdx]
    if (focused && typeof focused.scrollIntoView === "function") {
      focused.scrollIntoView({ block: "nearest" })
    }
  }

  #setStatus(msg) {
    const el = this.statusTarget
    el.textContent = msg
    el.classList.toggle("hidden", !msg)
  }

  // Simple inline i18n bridge — reads from data attributes if available,
  // falls back to English literals.  The sidebar ERB renders i18n into data
  // attributes on the controller element for zero-JS-bundle-size i18n.
  #t(key) {
    const map = {
      searching:      "Searching…",
      no_results:     "No results. Try a different title.",
      error:          "IGDB search failed. Check credentials.",
      in_library:     "In Library",
      in_library_hint: "(will resync)",
    }
    return this.element.dataset[`i18n${key.charAt(0).toUpperCase() + key.slice(1)}`] ?? map[key] ?? key
  }

  #cancelPending() {
    if (this._timer !== null) {
      clearTimeout(this._timer)
      this._timer = null
    }
    if (this._abort) {
      this._abort.abort()
      this._abort = null
    }
    this._requestId++
  }
}
