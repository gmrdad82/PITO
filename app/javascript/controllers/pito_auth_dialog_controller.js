import { Controller } from "@hotwired/stimulus"

/**
 * pito-auth-dialog — handles the TOTP / backup-code toggle on the
 * auth dialog overlay (Pito::AuthDialogComponent).
 *
 * The dialog renders:
 *   - `#auth-totp-field`   — 6-digit segmented TOTP input (shown by default)
 *   - `#auth-backup-field` — 8-char backup code input (hidden by default)
 *
 * The `[ use backup code ]` / `[ use TOTP code ]` toggle button swaps
 * visibility between them, clears the inactive field, and updates its own
 * label text (from data attrs: `data-use-backup-label` / `data-use-totp-label`).
 *
 * Targets:
 *   totpField   — the wrapper div containing the 6-segment TOTP component
 *   backupField — the wrapper div containing the backup-code input
 *   backupInput — the backup-code <input> element
 *   toggleBtn   — the toggle <button> whose label swaps between modes
 *
 * Actions:
 *   toggleBackup() — swap between TOTP and backup-code fields
 *
 * Note: the segmented TOTP input (digit boxes + hidden field) is managed
 * by the `totp-code-input` Stimulus controller on the TotpCodeInputComponent
 * wrapper. This controller does NOT interact with those cells directly.
 *
 * Z3-redesign (2026-05-25) — panel chrome + 6-segment input + bracketed
 * actions + toggle label swap + clipboard-copy integration.
 *
 * @contract see app/components/pito/auth_dialog_component.html.erb
 */
export default class extends Controller {
  static targets = ["totpField", "backupField", "backupInput", "toggleBtn"]

  toggleBackup() {
    const backupHidden = this.backupFieldTarget.hidden

    if (backupHidden) {
      // Switch to backup code mode
      this.backupFieldTarget.hidden = false
      this.totpFieldTarget.hidden = true
      if (this.hasBackupInputTarget) {
        this.backupInputTarget.focus()
      }
      // Swap toggle label to "[ use TOTP code ]"
      if (this.hasToggleBtnTarget) {
        const label = this.toggleBtnTarget.getAttribute("data-use-totp-label")
        this.toggleBtnTarget.querySelector(".bl").textContent = label
      }
    } else {
      // Switch back to TOTP mode
      this.backupFieldTarget.hidden = true
      this.totpFieldTarget.hidden = false
      if (this.hasBackupInputTarget) {
        this.backupInputTarget.value = ""
      }
      // Swap toggle label back to "[ use backup code ]"
      if (this.hasToggleBtnTarget) {
        const label = this.toggleBtnTarget.getAttribute("data-use-backup-label")
        this.toggleBtnTarget.querySelector(".bl").textContent = label
      }
      // Focus the first digit box after returning to TOTP mode
      const firstDigit = this.totpFieldTarget.querySelector("[data-totp-code-input-target='digit']")
      if (firstDigit) firstDigit.focus()
    }
  }
}
