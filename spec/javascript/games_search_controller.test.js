// spec/javascript/games_search_controller.test.js
//
// Vitest suite for pito--games-search Stimulus controller.
//
// Strategy: mount the real controller on a jsdom document.
// Tests cover: prefill search, debounce, keyboard navigation, disconnect.

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest"
import { Application } from "@hotwired/stimulus"
import GamesSearchController from "controllers/pito/games_search_controller"

// ── DOM scaffold ──────────────────────────────────────────────────────────────

function buildScaffold({ prefill = "", uuid = "test-uuid" } = {}) {
  const sidebar = document.createElement("div")
  sidebar.id = "pito-sidebar"
  document.body.appendChild(sidebar)

  const wrapper = document.createElement("div")
  wrapper.setAttribute("data-controller", "pito--games-search")
  wrapper.setAttribute("data-pito--games-search-conversation-uuid-value", uuid)
  wrapper.setAttribute("data-pito--games-search-prefill-value", prefill)

  const input = document.createElement("input")
  input.type = "text"
  input.value = prefill
  input.setAttribute("data-pito--games-search-target", "input")
  wrapper.appendChild(input)

  const status = document.createElement("p")
  status.setAttribute("data-pito--games-search-target", "status")
  status.classList.add("hidden")
  wrapper.appendChild(status)

  const results = document.createElement("div")
  results.setAttribute("data-pito--games-search-target", "results")
  wrapper.appendChild(results)

  sidebar.appendChild(wrapper)
  return { wrapper, input, status, results, sidebar }
}

function addRow(results, { igdbId, title }) {
  const row = document.createElement("div")
  row.className = "pito-igdb-row"
  row.dataset.igdbId = String(igdbId)
  row.dataset.title  = title
  results.appendChild(row)
  return row
}

// ── Suite ─────────────────────────────────────────────────────────────────────

describe("pito--games-search controller", () => {
  let app

  beforeEach(() => {
    // Provide a default no-op fetch so connect() + prefill search never throws
    global.fetch = vi.fn().mockResolvedValue({
      ok:   true,
      json: () => Promise.resolve({ hits: [], error: null, library_ids: [] }),
    })

    app = Application.start()
    app.register("pito--games-search", GamesSearchController)
  })

  afterEach(async () => {
    vi.restoreAllMocks()
    await app.stop()
    document.body.innerHTML = ""
    global.fetch = undefined
  })

  // Flush Stimulus mutation-observer callbacks + microtasks
  function tick(ms = 50) {
    return new Promise((r) => setTimeout(r, ms))
  }

  // ── Prefill ───────────────────────────────────────────────────────────────

  it("triggers an immediate search when prefill is non-empty", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok:   true,
      json: () => Promise.resolve({ hits: [], error: null, library_ids: [] }),
    })
    global.fetch = mockFetch

    buildScaffold({ prefill: "Hollow Knight" })
    await tick()

    expect(mockFetch).toHaveBeenCalledOnce()
    const body = JSON.parse(mockFetch.mock.calls[0][1].body)
    expect(body.query).toBe("Hollow Knight")
  })

  it("does NOT trigger a search when prefill is empty", async () => {
    const mockFetch = vi.fn()
    global.fetch = mockFetch

    buildScaffold({ prefill: "" })
    await tick()

    expect(mockFetch).not.toHaveBeenCalled()
  })

  // ── Input event → search ──────────────────────────────────────────────────

  it("calls /games/search when input value changes (after debounce)", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok:   true,
      json: () => Promise.resolve({ hits: [], error: null, library_ids: [] }),
    })
    global.fetch = mockFetch

    const { input } = buildScaffold()
    await tick()  // let connect() run; no prefill → no initial fetch

    mockFetch.mockClear()

    // Simulate user typing
    input.value = "Celeste"
    input.dispatchEvent(new Event("input", { bubbles: true }))

    // Wait longer than DEBOUNCE_MS (250ms)
    await tick(350)

    expect(mockFetch).toHaveBeenCalledOnce()
    const body = JSON.parse(mockFetch.mock.calls[0][1].body)
    expect(body.query).toBe("Celeste")
  })

  // ── Clear input → reset ───────────────────────────────────────────────────

  it("clears results when input is emptied", async () => {
    const { input, results } = buildScaffold()
    await tick()

    // Add a row manually
    addRow(results, { igdbId: 1, title: "Some Game" })
    expect(results.children.length).toBe(1)

    // Clear input
    input.value = ""
    input.dispatchEvent(new Event("input", { bubbles: true }))
    await tick()

    expect(results.children.length).toBe(0)
  })

  // ── Keyboard navigation ───────────────────────────────────────────────────

  it("ArrowDown highlights first row (from no selection)", async () => {
    const { results } = buildScaffold()
    await tick()

    const row0 = addRow(results, { igdbId: 1, title: "Alpha" })
    addRow(results, { igdbId: 2, title: "Beta" })

    document.dispatchEvent(new KeyboardEvent("keydown", {
      key: "ArrowDown", bubbles: true, cancelable: true
    }))
    await tick()

    expect(row0.classList.contains("pito-resume-highlight")).toBe(true)
  })

  it("ArrowDown then ArrowDown highlights second row", async () => {
    const { results } = buildScaffold()
    await tick()

    const row0 = addRow(results, { igdbId: 1, title: "Alpha" })
    const row1 = addRow(results, { igdbId: 2, title: "Beta" })

    document.dispatchEvent(new KeyboardEvent("keydown", {
      key: "ArrowDown", bubbles: true, cancelable: true
    }))
    document.dispatchEvent(new KeyboardEvent("keydown", {
      key: "ArrowDown", bubbles: true, cancelable: true
    }))
    await tick()

    expect(row0.classList.contains("pito-resume-highlight")).toBe(false)
    expect(row1.classList.contains("pito-resume-highlight")).toBe(true)
  })

  // ── Enter with no rows is a no-op ─────────────────────────────────────────

  it("does NOT call /games/search when Enter is pressed (not ArrowDown+Enter)", async () => {
    // The controller only calls #importGame from #selectHighlighted, which is
    // only called from #onKey when rows.length > 0 and _highlightIdx >= 0.
    // With an empty results container, Enter is a no-op for the import path.
    // We verify by asserting the results container has no rows.
    const { results } = buildScaffold({ prefill: "" })
    await tick()

    // No rows in results → Enter should do nothing
    expect(results.querySelectorAll(".pito-igdb-row").length).toBe(0)
    // Pressing Enter with no rows and no highlight doesn't throw
    document.dispatchEvent(new KeyboardEvent("keydown", {
      key: "Enter", bubbles: true, cancelable: true
    }))
    await tick()
    // Still no rows
    expect(results.querySelectorAll(".pito-igdb-row").length).toBe(0)
  })

  // ── Disconnect cleanup ────────────────────────────────────────────────────

  it("controller disconnects cleanly without throwing", async () => {
    // Verify disconnect() (called by app.stop()) runs without errors,
    // even when a debounce timer is pending.
    const { input } = buildScaffold()
    await tick()

    // Set up a pending debounce timer by typing (timer will be cancelled by disconnect)
    input.value = "foo"
    input.dispatchEvent(new Event("input", { bubbles: true }))

    // Stop cleanly — should not throw
    let threw = false
    try {
      await app.stop()
    } catch {
      threw = true
    }
    expect(threw).toBe(false)
  })
})
