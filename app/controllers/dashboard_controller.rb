class DashboardController < ApplicationController
  # Home (/) — Phase 2D (2026-05-23). Layout shell wired with the 3-row
  # C3 + masonry row 3 grid (see `app/views/dashboard/index.html.erb`).
  # Most panels render blank in this round; the ex-settings panels
  # (Security, Notifications, Stack) need ivars to satisfy their
  # ViewComponent constructors — fed here with minimum stub data so the
  # render is green. Real data wiring (live probes, current_user
  # sessions, webhook records) lands in subsequent content rounds.
  #
  # JSON branch retained as the CLI's canonical `get_dashboard` envelope
  # so `pito` deserializes cleanly. Shape: video_count + channel_count +
  # footage_count.

  def index
    respond_to do |format|
      format.html { set_panel_stub_ivars }
      format.json { render json: dashboard_json }
    end
  end

  private

  # Phase 2D — stub data for the layout-shell render. Each ivar matches
  # the keyword arg one of the rescued ex-settings ViewComponents
  # demands. When the content rounds wire live data per panel, the
  # corresponding stub assignment here gets replaced with a real lookup
  # (probe service, current_user.sessions scope, etc.) — never invent
  # values; values come from the canonical source.
  def set_panel_stub_ivars
    # Pito::SecurityPanelComponent kwargs.
    @sessions      = Session.none
    @sessions_sort = "last_seen"
    @sessions_dir  = "desc"

    # Pito::NotificationsPanelComponent kwargs.
    @discord_webhook = nil
    @slack_webhook   = nil

    # Pito::StackPanelComponent kwargs.
    @postgres_status          = { connected: false }
    @postgres_table_breakdown = []
    @search_healthy           = false
    @search_stats             = {}
    @search_per_index_stats   = []
    @voyage_configured        = false
    @storage_status           = { present: false, writable: false }
    @assets_breakdown         = []
    @sidekiq_breakdown        = []
    @redis_status             = { connected: false }
  end

  def dashboard_json
    {
      video_count:   Video.count,
      channel_count: Channel.count,
      footage_count: Footage.count
    }
  end
end
