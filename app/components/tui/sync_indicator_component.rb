module Tui
  # Tui::SyncIndicatorComponent — checkbox-style sync indicator.
  #
  # 2026-05-24 (Phase 1D) — unified replacement for the now-deleted
  # `Tui::PauseControlComponent`. Renders `[ ] sync` / `[x] sync` /
  # `[-] sync` / `[!] sync` checkbox+word display in TWO contexts:
  #
  #   1. `mode: :tst` (default) — aggregate read-only indicator in the
  #      top status bar. Not clickable. Reflects global cable activity
  #      across every enabled target.
  #
  #   2. `mode: :target` — interactive per-panel / per-sub-panel control
  #      mounted in a panel or sub-panel's title-actions slot. Clicking
  #      toggles a `pito.sync.<target>` AppSetting row between "yes"
  #      (enabled, default) and "no" (disabled). Disabling a panel-level
  #      target suppresses cable broadcasts for every descendant
  #      sub-panel; disabling a sub-panel target suppresses that target
  #      alone.
  #
  # ## Six canonical states (A3 — 2026-05-25)
  #
  # | State        | Glyph | Color           | Shimmer | When                                                            |
  # |--------------|-------|-----------------|---------|-----------------------------------------------------------------|
  # | idle         | [ ]   | accent          | no      | Self-flag = "no", or no enabled targets / no activity.          |
  # | active       | [x]   | accent          | no      | Enabled + has active work (Sidekiq busy/enqueued/retry > 0).    |
  # | syncing      | [x]   | accent          | yes     | THIS target currently receiving cable content (shimmer on word) |
  # | paused       | [-]   | muted           | no      | Explicitly paused by user (cable kind: "pause").                |
  # | uncertain    | [-]   | accent          | no      | Mixed sub-panel flags OR indeterminate external state.          |
  # | disconnected | [!]   | danger (red)    | no      | Cable connection failed / syncing not available.                |
  #
  # `mixed` is a deprecated alias for `uncertain`. Passing `state: "mixed"`
  # still works but emits a Rails.logger.warn once per process.
  #
  # ## Paused vs Uncertain visual distinction
  #
  # Both `paused` and `uncertain` emit the `[-] sync` glyph. They are
  # distinguished by color:
  #
  #   paused    → `var(--color-muted)` (gray, CSS class `.is-muted`)
  #   uncertain → `var(--section-accent)` (CSS class `.is-accent`, default)
  #
  # An `aria-label` also distinguishes them at the accessibility layer
  # (controller swaps this at runtime based on the cable kind).
  #
  # ## Kwargs
  #
  # @param mode [Symbol] `:tst` (default) or `:target`.
  # @param state [Symbol] SSR initial state: one of `:idle`, `:active`,
  #   `:syncing`, `:paused`, `:uncertain`, `:disconnected`. Defaults to
  #   the AppSetting-derived state when omitted.
  #   `"mixed"` is accepted as a deprecated alias for `:uncertain`.
  # @param target [String, Symbol] (only `:target` mode) dot-namespaced
  #   target key, e.g. `"home.stack"` or `"home.stack.meilisearch"`.
  # @param parent_target [String, Symbol, nil] (only `:target` mode)
  #   dot-namespaced target of the containing panel for sub-panels.
  # @param focusable_key [String, Symbol, nil] (only `:target` mode) when
  #   present, emits `data-tui-focusable=<key>` so j/k cursor can land on
  #   it. Style = `action`.
  #
  # ## Cable contract (`:tst` mode)
  #
  # Listens for `tui:cable-activity` and `tui:sync-changed` on document.
  # Also handles `kind: "pause"` and `kind: "uncertain"` from
  # `Pito::CableBroadcaster` (A8). The controller derives idle / active /
  # syncing / paused / uncertain / disconnected from the combined signal.
  #
  # ## Cable contract (`:target` mode)
  #
  # Click → POST `/sync/toggle` → server cascades write + broadcasts on
  # `pito:sync_state`. Cable kind `"pause"` → paint `paused`.
  # Cable kind `"uncertain"` → paint `uncertain`.
  #
  # ## i18n
  #
  # The word "sync" comes from `config/locales/tui/en.yml` `tui.tst.sync.*`.
  # All per-state full display strings are emitted as data-* attrs.
  #
  # @contract see docs/design.md § Transitions
  class SyncIndicatorComponent < ViewComponent::Base
    include Tui::Transitionable

    MODES  = %i[tst target].freeze
    STATES = %i[idle active syncing paused uncertain mixed disconnected].freeze
    DEFAULT_MODE  = :tst
    DEFAULT_STATE = :idle

    # Deprecated aliases: old state name → canonical state name.
    STATE_ALIASES = { mixed: :uncertain }.freeze
    private_constant :STATE_ALIASES

    # Sentinel for "no `state:` argument passed". Distinct from `:idle`
    # so an explicit `state: :idle` (spec fixtures + top-status-bar)
    # still wins over the AppSetting-derived initial state.
    STATE_UNSET = Object.new.freeze
    private_constant :STATE_UNSET

    def initialize(mode: DEFAULT_MODE, state: STATE_UNSET,
                   target: nil, parent_target: nil, focusable_key: nil)
      @mode  = MODES.include?(mode.to_sym) ? mode.to_sym : DEFAULT_MODE
      @target = target&.to_s
      @parent_target = parent_target&.to_s
      @focusable_key = focusable_key&.to_s

      if @mode == :target && @target.nil?
        raise ArgumentError, "Tui::SyncIndicatorComponent mode: :target requires target:"
      end

      # 2026-05-25 (sync-rebuild) — server-side initial state. Reads
      # the canonical AppSetting row so the HTML lands with the right
      # glyph from the SSR pass. No client-side localStorage lookup,
      # no flash-of-wrong-state. The `state:` kwarg still wins when
      # explicitly passed (used by the top-status-bar aggregate
      # indicator + spec fixtures); otherwise the AppSetting-derived
      # state is the default.
      @state = if state.equal?(STATE_UNSET)
        derive_initial_state
      else
        normalize_state(state.to_sym)
      end
    end

    attr_reader :mode, :state, :target, :parent_target, :focusable_key

    def target_mode?
      @mode == :target
    end

    def tst_mode?
      @mode == :tst
    end

    def state_word
      case @state
      when :active, :syncing               then I18n.t("tui.tst.sync.active")
      when :paused, :uncertain             then I18n.t("tui.tst.sync.mixed", default: I18n.t("tui.tst.sync.idle"))
      when :disconnected                   then I18n.t("tui.tst.sync.disconnected", default: I18n.t("tui.tst.sync.idle"))
      else                                      I18n.t("tui.tst.sync.idle")
      end
    end

    def checkbox_glyph
      case @state
      when :active, :syncing  then "[x]"
      when :disconnected      then "[!]"
      when :paused, :uncertain then "[-]"
      else                         "[ ]"
      end
    end

    def display_value
      "#{checkbox_glyph} #{state_word}"
    end

    def word_idle
      "[ ] #{I18n.t("tui.tst.sync.idle")}"
    end

    def word_active
      "[x] #{I18n.t("tui.tst.sync.active")}"
    end

    def word_syncing
      "[x] #{I18n.t("tui.tst.sync.active")}"
    end

    # Deprecated — kept for callers that read this helper directly.
    # Returns the `uncertain` display string (same as word_uncertain).
    def word_mixed
      word_uncertain
    end

    def word_paused
      "[-] #{I18n.t("tui.tst.sync.mixed", default: I18n.t("tui.tst.sync.idle"))}"
    end

    def word_uncertain
      "[-] #{I18n.t("tui.tst.sync.mixed", default: I18n.t("tui.tst.sync.idle"))}"
    end

    def word_disconnected
      "[!] #{I18n.t("tui.tst.sync.disconnected", default: I18n.t("tui.tst.sync.idle"))}"
    end

    # Builds the merged data-attrs hash for the host span.
    def root_data_attrs
      base = transitionable_attrs(
        value: display_value,
        align: :right,
        color: color_for(@state),
        shimmer: @state == :syncing
      )
      attrs = base[:data]
      attrs[:controller] = "tui-sync-indicator #{attrs[:controller]}"
      attrs[:tui_sync_indicator_mode_value]         = @mode.to_s
      attrs[:tui_sync_indicator_idle_value]         = word_idle
      attrs[:tui_sync_indicator_active_value]       = word_active
      attrs[:tui_sync_indicator_syncing_value]      = word_syncing
      attrs[:tui_sync_indicator_mixed_value]        = word_uncertain
      attrs[:tui_sync_indicator_paused_value]       = word_paused
      attrs[:tui_sync_indicator_uncertain_value]    = word_uncertain
      attrs[:tui_sync_indicator_disconnected_value] = word_disconnected
      # 2026-05-25 — UNIQUE outlet selector per VC instance. The previous
      # `.tui-sync-word` selector matched EVERY sync VC in the document;
      # every panel sync controller's `this.tuiTransitionOutlet` resolved
      # to the TST's transition controller (first match wins), so every
      # toggle painted the TST glyph instead of the focused panel's
      # glyph. Sanitized-target class per instance solves it.
      instance_class = "tui-sync-word--id-#{instance_outlet_id}"
      attrs[:class] = [ attrs[:class], instance_class ].compact.join(" ")
      attrs[:tui_sync_indicator_tui_transition_outlet] = ".#{instance_class}"
      attrs[:tui_status_bar_target] = "sync" if tst_mode?

      if target_mode?
        attrs[:tui_sync_indicator_target_value] = @target
        attrs[:tui_sync_indicator_parent_target_value] = @parent_target if @parent_target
        # 2026-05-24 — only `click` is wired. Native <button> already
        # converts SPACE / Enter keydown into a click event, AND the
        # `tui_cursor_controller`'s INSERT-mode SPACE handler does an
        # `el.click()` on the focused button (see
        # `toggleFocusedFocusableCheckbox`). Adding explicit
        # `keydown.space->toggle keydown.enter->toggle` actions on top of
        # those two paths caused a double-fire that toggled the sync flag
        # twice (net zero) every keystroke. The cursor controller +
        # native button activation are the single canonical paths.
        attrs[:action] = "click->tui-sync-indicator#toggle"
        if @focusable_key
          attrs[:tui_focusable] = @focusable_key
          attrs[:tui_focusable_key] = @focusable_key
          attrs[:tui_focusable_style] = "action"
        end
      end

      attrs
    end

    # 2026-05-25 — unique outlet selector per VC instance.
    # TST → "tst" (only one TST per page).
    # Target mode → sanitized target (e.g. "home-stack-meilisearch").
    def instance_outlet_id
      return "tst" if tst_mode?
      @target.to_s.tr(".", "-")
    end

    # Aria label for `:target` mode rendering. The controller swaps the
    # value at runtime once it knows the live state.
    def aria_label
      I18n.t("tui.sync_indicator.aria.idle", default: "sync")
    end

    private

    # Normalize a state symbol, handling deprecated aliases and
    # unknown values. Emits a logger.warn for deprecated aliases.
    def normalize_state(sym)
      if STATE_ALIASES.key?(sym)
        Rails.logger.warn(
          "Tui::SyncIndicatorComponent: state '#{sym}' is deprecated; " \
          "use '#{STATE_ALIASES[sym]}'"
        )
        return STATE_ALIASES[sym]
      end
      STATES.include?(sym) ? sym : DEFAULT_STATE
    end

    # 2026-05-25 (sync-rebuild) — derive the SSR-initial state from the
    # canonical AppSetting rows. Logic:
    #
    #   :tst mode    → reads `sync.app` (master) for enabled/idle;
    #                  then checks `Pito::SyncState` for paused/uncertain.
    #   :target mode → walks the suppression chain (parent + "app"); if any
    #                  link is disabled → :idle. Then checks the pause-layer:
    #                  if self is paused → :paused; if mixed children → :uncertain.
    #
    # 2026-05-25 (pause-from-sync) — pause state layered on top of the
    # enable gate. Paused takes priority over active; uncertain reflects
    # mixed child state (some children paused, some not).
    def derive_initial_state
      if tst_mode?
        return :idle unless AppSetting.sync_enabled?("app")
        # Even when globally enabled, reflect any broad pause state.
        pause_state = Pito::SyncState.state("app")
        return :paused    if pause_state == :paused
        return :uncertain if pause_state == :uncertain
        return :active
      end
      chain = Pito::SyncTargets.suppression_chain(@target) || [ @target ]
      enabled = chain.all? { |t| AppSetting.sync_enabled?(t) }
      return :idle unless enabled

      # Enabled — now check the pause layer.
      pause_state = Pito::SyncState.state(@target)
      return :paused    if pause_state == :paused
      return :uncertain if pause_state == :uncertain
      :active
    rescue StandardError
      # Defensive: tests render the VC without a DB row; fall back to
      # the documented default. Production has the table; the rescue
      # only kicks in for in-memory render-without-DB tests.
      DEFAULT_STATE
    end

    # Color name maps to the `kind=sync` row of the tui-transition
    # controller's COLOR_CLASS table:
    #   accent → no class (default `.tui-sync-word` color)
    #   muted  → `.is-muted` (paused state — gray, not an action)
    #   pink   → `.is-pink` (var(--color-danger), disconnected)
    #
    # Visual distinction between paused and uncertain:
    #   paused    → muted (gray) — user deliberately paused; not an action
    #   uncertain → accent       — system state, still "alive", accent voice
    def color_for(state)
      case state
      when :disconnected then :pink
      when :paused       then :muted
      else                    :accent
      end
    end
  end
end
