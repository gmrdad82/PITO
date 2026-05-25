# Pito::AuthDialogComponent — non-dismissible TOTP login overlay.
#
# Purpose:
#   Renders a full-viewport overlay dialog when `Current.session.nil?`.
#   The root layout always serves; this dialog sits on top of the panel
#   chrome so the owner can see the structural skeleton without seeing
#   live data.
#
# Kwargs: none required.
#
# Variants: none.
#
# Focusables:
#   - `#auth-code`        — primary 6-digit TOTP input (autofocused)
#   - `#auth-backup-code` — 8-char backup code input (revealed via toggle)
#   - submit button
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
