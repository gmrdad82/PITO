module Tui
  # Beta 4 — extracted from `Tui::TopStatusBarComponent` (2026-05-21)
  # per "ViewComponents are kings" — sub-elements of the top status
  # bar each get their own VC + spec.
  #
  # Sidekiq queue-depth stats cells: `b<n> e<n> r<n>`. Each cell
  # carries `.sb-sk-cell` plus a state class (`.sk-zero` muted when
  # the count is 0, `.sk-b` / `.sk-e` / `.sk-r` colored when non-zero).
  #
  # Constructor inputs:
  #   - busy:      integer (default 0)
  #   - enqueued:  integer (default 0)
  #   - retry:     integer (default 0) — accepted via kwarg
  #                `retry:` despite being a Ruby keyword (safe in
  #                kwargs context).
  #
  # The `scheduled` count is intentionally NOT rendered here — the
  # bar shows three of the four counts. `scheduled` is a future
  # surface (per-subsystem stack panel).
  #
  # Cells carry `data-tui-status-bar-target="sidekiqBusy"` etc. so
  # `tui_status_bar_controller.js` can patch them in place when the
  # `pito:status_bar` cable pushes new counts.
  #
  # 2026-05-22 — Now also carries the `tui-sidekiq-stats` Stimulus
  # controller which listens for `tui:sidekiq-changed` custom DOM
  # events (dispatched by the parent `tui-top-status-bar` controller on
  # every `data` payload). Color rules locked here:
  #
  #   busy > 0      → .sk-b (var(--color-success), green)
  #   enqueued > 0  → .sk-e (var(--color-muted),  muted) — orange historically
  #   retry > 0     → .sk-r (var(--color-danger), pink)
  #   any count 0   → .sk-zero (muted)
  #
  # Letter prefixes (`b` / `e` / `r`) come from i18n keys
  # `tui.tst.sidekiq.busy_prefix` etc. so the JS layer can rebuild
  # `b<N>` / `e<N>` / `r<N>` without inlining English literals.
  class SidekiqStatsComponent < ViewComponent::Base
    def initialize(**kwargs)
      @counts = {
        busy:     kwargs.fetch(:busy, 0).to_i,
        enqueued: kwargs.fetch(:enqueued, 0).to_i,
        retry:    kwargs.fetch(:retry, 0).to_i
      }
    end

    # Letter → count lookup so the template stays a flat list of
    # three cells driven by a single helper.
    def value_for(letter)
      @counts.fetch(letter_to_key(letter), 0)
    end

    def cell_class_for(letter)
      value = value_for(letter)
      return "sb-sk-cell sk-zero" if value.zero?

      "sb-sk-cell sk-#{letter}"
    end

    def target_for(letter)
      case letter.to_s
      when "b" then "sidekiqBusy"
      when "e" then "sidekiqEnqueued"
      when "r" then "sidekiqRetry"
      end
    end

    def prefix_for(letter)
      case letter.to_s
      when "b" then I18n.t("tui.tst.sidekiq.busy_prefix")
      when "e" then I18n.t("tui.tst.sidekiq.enqueued_prefix")
      when "r" then I18n.t("tui.tst.sidekiq.retry_prefix")
      end
    end

    private

    def letter_to_key(letter)
      case letter.to_s
      when "b" then :busy
      when "e" then :enqueued
      when "r" then :retry
      else letter.to_sym
      end
    end
  end
end
