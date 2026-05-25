# Read-only security dashboard.
#
# Surfaces 2FA status. Post-Phase-25 rollback, the per-attempt /
# blocked-location / pending-session counters and the recent-attempt
# table are gone with the new-location approval surface; the dashboard
# now carries the 2FA status line only.
#
# Auth: same `Sessions::AuthConcern` gate as every other settings
# surface.
class Settings::SecurityController < ApplicationController
  def show
    # Z1: User model gone; TOTP state now lives on AppSetting singleton.
    @twofa_enabled = AppSetting.instance.totp_enabled? rescue false
  end
end
