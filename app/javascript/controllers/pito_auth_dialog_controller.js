import { Controller } from "@hotwired/stimulus"

/**
 * pito-auth-dialog — handles the TOTP / backup-code toggle on the
 * auth dialog overlay (Pito::AuthDialogComponent).
 *
 * The dialog renders two input fields:
 *   - `#auth-code`        — 6-digit TOTP (shown by default)
 *   - `#auth-backup-code` — 8-char backup code (hidden by default)
 *
 * The "use a backup code" toggle button swaps visibility between them
 * and clears the inactive field so a stale value can't be accidentally
 * submitted.
 *
 * Targets:
 *   backupField  — the wrapper div containing the backup-code input
 *   codeInput    — the primary 6-digit input
 *   backupInput  — the backup-code input
 *
 * Actions:
 *   toggleBackup() — swap between TOTP and backup-code fields
 *
 * Note: this controller uses `data-action="click->pito-auth-dialog#toggleBackup"`
 * on the toggle button; the form wrapper also mounts this controller
 * (identifier matches) so targets resolve correctly within the dialog.
 *
 * Z3 (2026-05-25) — initial implementation.
 *
 * @contract see app/components/pito/auth_dialog_component.html.erb
 */
export default class extends Controller {
  static targets = ["backupField", "codeInput", "backupInput"]

  toggleBackup() {
    const backupHidden = this.backupFieldTarget.hidden

    if (backupHidden) {
      // Switch to backup code mode
      this.backupFieldTarget.hidden = false
      if (this.hasCodeInputTarget) {
        this.codeInputTarget.value = ""
      }
      if (this.hasBackupInputTarget) {
        this.backupInputTarget.focus()
      }
    } else {
      // Switch back to TOTP mode
      this.backupFieldTarget.hidden = true
      if (this.hasBackupInputTarget) {
        this.backupInputTarget.value = ""
      }
      if (this.hasCodeInputTarget) {
        this.codeInputTarget.focus()
      }
    }
  }
}
