# Phase 26 — 01a. Timezone foundation.
#
# Single `update` endpoint for the authenticated user's `time_zone`.
# Two callers:
#
#   1. The Stimulus `timezone-detect` controller, mounted on `<body>`
#      on every authenticated page. On first load (when the user's
#      stored zone is still `"Etc/UTC"` — the "never set" sentinel)
#      it POSTs the browser-detected zone from
#      `Intl.DateTimeFormat().resolvedOptions().timeZone`. Silent
#      success: 204 on persist, 422 on validation failure (the JS
#      ignores the response either way — silent failure is fine).
#
#   2. The Settings page dropdown (`_time_zone_pane.html.erb`).
#      Normal form submit; success redirects back to `/settings`
#      with a flash notice.
#
# Both callers hit the same `time_zone` param shape. The controller
# distinguishes the two by `request.format` — HTML for the form,
# anything else (including the default Stimulus fetch) for the JS
# branch.
class Settings::TimeZoneController < ApplicationController
  def update
    new_tz = params[:time_zone].to_s

    # Z1: User model gone. Time zone is now a no-op (fixed to Etc/UTC
    # in ApplicationController#set_user_time_zone). This endpoint is
    # preserved for the Stimulus timezone-detect controller which silently
    # POST-and-ignores; it always returns 204 to avoid JS errors.
    respond_to do |format|
      format.html { redirect_to settings_path, notice: t("settings.time_zone.flash.saved") }
      format.any  { head :no_content }
    end
  end
end
