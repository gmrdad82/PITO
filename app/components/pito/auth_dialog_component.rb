# Pito::AuthDialogComponent — non-dismissible TOTP login overlay.
#
# Purpose:
#   Renders a full-viewport overlay dialog when `Current.session.nil?`.
#   The root layout always serves; this dialog sits on top of the panel
#   chrome so the owner can see the structural skeleton without seeing
#   live data.
#
#   Visual pattern: adopts the canonical `.pito-pane` chrome (border-radius,
#   section-accent border, title-in-border via `.pito-pane__title`). The
#   6-digit TOTP input renders as TotpCodeInputComponent (six segmented
#   boxes + hidden concatenation field). A backup-code field is toggled
#   via the `pito-auth-dialog` Stimulus controller. When TOTP is not yet
#   enrolled, a code-block hint appears with a `[ copy ]` action backed by
#   the `clipboard-copy` Stimulus controller.
#
# Kwargs: none required.
#
# Variants: none.
#
# Focusables:
#   - digit boxes (6)     — primary TOTP segmented input (autofocused on digit 1)
#   - `#auth-backup-code` — 8-char backup code input (revealed via toggle)
#   - `[ log in ]`        — submit button
#   - `[ use backup code ]` / `[ use TOTP code ]` — toggle button
#   - `[ copy ]`          — clipboard action (only when totp_not_enrolled?)
#
# Mode behavior:
#   Unconditionally shown when the layout detects `Current.session.nil?`.
#   Not dismissible by keyboard (Esc / backdrop). Disappears only on a
#   successful POST /login which triggers a full-page reload.
#
# Cable subscriptions: none (unauthenticated context; cable never opens).
#
# Related:
#   app/views/layouts/application.html.erb — renders this component
#   app/controllers/sessions_controller.rb — handles POST /login
#   app/helpers/application_helper.rb      — tui_authenticated?
#   app/components/totp_code_input_component.rb — 6-box segmented input
#   app/javascript/controllers/pito_auth_dialog_controller.js — toggle + label swap
#   app/javascript/controllers/clipboard_copy_controller.js — [ copy ] action
#   config/locales/tui/en.yml              — tui.auth.* keys
class Pito::AuthDialogComponent < ViewComponent::Base
  # Returns true when TOTP has not been enrolled yet.
  # Used to render the operator hint in the dialog body.
  def totp_not_enrolled?
    !AppSetting.totp_enabled?
  end

  # The flash alert from the previous failed POST /login attempt.
  # Reads from the Rails flash; nil when no prior failure.
  def login_error
    helpers.flash[:alert].presence
  end
end
