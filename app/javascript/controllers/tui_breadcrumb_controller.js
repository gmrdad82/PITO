import { Controller } from "@hotwired/stimulus"

// Beta 4 — Phase F1 child controller for `Tui::BreadcrumbComponent`.
// Listens for the existing `tui:panel-focus-changed` custom event
// emitted by `tui_cursor_controller.js` and patches the breadcrumb
// segment in place so the right side of the bar always reflects the
// focused panel / sub-panel.
//
// Event contract (already established by tui-cursor):
//
//   detail: {
//     panel:     "<panel title>" | undefined,
//     title:     "<panel title>" | undefined,   // alternate key tui-cursor used
//     subPanel:  "<sub-panel title>" | null
//   }
//
// When `subPanel` is null → render `<panel>` as a single text node.
// When `subPanel` is set  → render the four-span layout
//   `<panel-span>:(<sub-panel-span>)` matching design.md's accent +
//   muted-paren pattern.
//
// On disconnect we tear down the listener so a Turbo morph doesn't
// double-fire.
export default class extends Controller {
  static values = {
    screen: String
  }

  connect() {
    this.boundFocus = this.handleFocus.bind(this)
    document.addEventListener("tui:panel-focus-changed", this.boundFocus)
    // Seed from the currently focused panel if `tui-cursor` already
    // dispatched its initial event before we registered the listener.
    this.seedFromFocusedPanel()
  }

  disconnect() {
    if (this.boundFocus) {
      document.removeEventListener("tui:panel-focus-changed", this.boundFocus)
      this.boundFocus = null
    }
  }

  handleFocus(event) {
    const detail = event?.detail || {}
    const panel = detail.panel ?? detail.title ?? ""
    const subPanel = detail.subPanel || null
    if (!panel) return
    this.render(panel, subPanel)
  }

  seedFromFocusedPanel() {
    const focused = document.querySelector(
      '[data-tui-cursor-target="panel"][data-tui-cursor-focused="yes"]'
    )
    const title = focused?.dataset?.panelTitle
    if (!title) return
    const subFocused = focused.querySelector(
      '[data-tui-cursor-target="sub-panel"][data-tui-cursor-sub-panel-focused="yes"]'
    )
    const subTitle = subFocused?.dataset?.panelTitle || null
    this.render(title, subTitle)
  }

  render(panel, subPanel) {
    const el = this.element
    while (el.firstChild) el.removeChild(el.firstChild)
    if (!subPanel) {
      el.appendChild(document.createTextNode(panel))
      return
    }
    const panelSpan = document.createElement("span")
    panelSpan.className = "sb-section__panel"
    panelSpan.textContent = panel
    const parenOpen = document.createElement("span")
    parenOpen.className = "sb-section__sub-panel-paren"
    parenOpen.textContent = ":("
    const subSpan = document.createElement("span")
    subSpan.className = "sb-section__sub-panel"
    subSpan.textContent = subPanel
    const parenClose = document.createElement("span")
    parenClose.className = "sb-section__sub-panel-paren"
    parenClose.textContent = ")"
    el.appendChild(panelSpan)
    el.appendChild(parenOpen)
    el.appendChild(subSpan)
    el.appendChild(parenClose)
  }
}
