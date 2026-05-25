class DashboardController < ApplicationController
  # Home (/) — Phase 2D (2026-05-23). Layout shell wired with the 3-row
  # C3 + masonry row 3 grid (see `app/views/dashboard/index.html.erb`).
  #
  # C19f follow-up (2026-05-23). The three rescued ex-settings panels
  # (Security, Notifications, Stack) need real data — the prior stub
  # path fed `false`/`nil`/`[]` and the panels rendered empty (no
  # session rows, no Stack subsystem rows, etc.). Data fetching now
  # lives in `Concerns::HomePanelData`, mixed in below; each rescued
  # panel has its own `set_*_panel_data` method run via before_action
  # so DashboardController stays readable.
  #
  # The remaining home-native panels (Aggregator, Calendar, PersonalStats,
  # ApiQuota, NotificationsFeed) still render blank in this round; their
  # real data wiring lands in subsequent content rounds, each via its
  # own panel-scoped controller action + cable broadcast.
  #
  # JSON branch retained as the CLI's canonical `get_dashboard` envelope
  # so `pito` deserializes cleanly. Shape: video_count + channel_count +
  # footage_count.
  #
  # Z3 (2026-05-25) — auth dialog overlay. The root path is now always
  # served regardless of auth state. Unauthenticated visitors see the
  # panel chrome skeleton behind `Pito::AuthDialogComponent`. The data
  # before_actions only run when a session is present so expensive stack
  # probes don't fire on the unauthenticated path.
  include HomePanelData

  allow_anonymous :index

  before_action :set_security_panel_data,             only: :index, if: :authenticated_html_request?
  before_action :set_notifications_panel_data,        only: :index, if: :authenticated_html_request?
  before_action :set_stack_panel_data,                only: :index, if: :authenticated_html_request?
  before_action :set_calendar_panel_data,             only: :index, if: :authenticated_html_request?
  before_action :assemble_home_panel_data,            only: :index

  def index
    respond_to do |format|
      format.html
      format.json { render json: dashboard_json }
    end
  end

  private

  def html_request?
    request.format.html?
  end

  # Z3 (2026-05-25) — gate data fetches on authenticated HTML requests.
  # Unauthenticated requests still render the layout + auth dialog overlay
  # but skip expensive panel probes (stack health, session rows, etc.).
  def authenticated_html_request?
    request.format.html? && Current.session.present?
  end

  def dashboard_json
    {
      video_count:   Video.count,
      channel_count: Channel.count,
      footage_count: Footage.count
    }
  end
end
