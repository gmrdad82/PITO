import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "headerCheckbox", "actions", "count",
                     "bulkCol", "actionCol", "bulkToggle", "openAction", "openHint",
                     "deleteAction"]
  static values = { maxPanes: Number, entityName: String, panesPath: String, deleteType: String }

  enterBulk(event) {
    event.preventDefault()
    this.bulkColTargets.forEach(el => el.hidden = false)
    this.actionColTargets.forEach(el => el.hidden = true)
    this.bulkToggleTarget.hidden = true
    this.actionsTarget.hidden = false
    this.updateActions()
  }

  exitBulk(event) {
    event.preventDefault()
    this.bulkColTargets.forEach(el => el.hidden = true)
    this.actionColTargets.forEach(el => el.hidden = false)
    this.bulkToggleTarget.hidden = false
    this.actionsTarget.hidden = true
    this.checkboxTargets.forEach(cb => cb.checked = false)
    if (this.hasHeaderCheckboxTarget) {
      this.headerCheckboxTarget.checked = false
      this.headerCheckboxTarget.indeterminate = false
    }
  }

  toggle() {
    this.updateActions()
  }

  toggleAll() {
    const checked = this.headerCheckboxTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateActions()
  }

  updateActions() {
    const count = this.selectedIds.length
    const max = this.maxPanesValue
    const name = this.entityNameValue

    // update count display
    this.countTarget.textContent = count

    const ids = this.selectedIds.join(",")

    // update open action
    if (count === 0) {
      this.openHintTarget.hidden = false
      this.openActionTarget.hidden = true
      this.openHintTarget.innerHTML = `<span class="text-muted">select items to act on</span>`
    } else if (count <= max) {
      this.openHintTarget.hidden = true
      this.openActionTarget.hidden = false
      const panesUrl = `${this.panesPathValue}?ids=${ids}`
      this.openActionTarget.innerHTML = `<a href="${panesUrl}" class="bracketed">[ <span class="bl">open ${count} ${name}</span> ]</a>`
    } else {
      this.openHintTarget.hidden = false
      this.openActionTarget.hidden = true
      this.openHintTarget.innerHTML = `<span class="text-muted">max ${max} ${name} at a time</span>`
    }

    // update delete action
    if (this.hasDeleteActionTarget) {
      if (count > 0) {
        const ref = encodeURIComponent(window.location.pathname + window.location.search + window.location.hash)
        const deleteUrl = `/deletions?type=${this.deleteTypeValue}&ids=${ids}&ref=${ref}`
        this.deleteActionTarget.innerHTML = `<a href="${deleteUrl}" class="bracketed text-danger">[ <span class="bl">delete ${count}</span> ]</a>`
        this.deleteActionTarget.hidden = false
      } else {
        this.deleteActionTarget.hidden = true
      }
    }

    // sync header checkbox
    if (this.hasHeaderCheckboxTarget) {
      const total = this.checkboxTargets.length
      this.headerCheckboxTarget.checked = count > 0 && count === total
      this.headerCheckboxTarget.indeterminate = count > 0 && count < total
    }
  }

  get selectedIds() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }
}
