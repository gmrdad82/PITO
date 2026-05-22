module Tui
  # Beta 4 — Phase 2E upgrades the breadcrumb to a multi-color segmented
  # value so the panel title and the sub-panel title can render in
  # distinct colors within the SAME tui-transition host (no DOM split).
  #
  # Visual contract (3-state):
  #   - idle (no panel focused) → renders the screen name (e.g. "home")
  #     in ACCENT-PALE (washed-out home-accent purple, distinct from
  #     --color-muted which is owned by AppVersion). No segments.
  #   - panel only              → renders "<panel>" in ACCENT. The host
  #     color is accent; no segments emitted (the whole value inherits
  #     the host color via the tui-transition palette).
  #   - panel + sub-panel       → renders "<panel>:(<sub-panel>)" with
  #     segments overriding the host color per character range:
  #       · panel chars             → accent-pale
  #       · ":(" delimiter chars    → accent-pale (inherited via host)
  #       · sub-panel chars         → accent
  #       · ")" closing char        → accent-pale (inherited via host)
  #     The host color is set to ACCENT-PALE so the un-segmented ranges
  #     (":(" and ")") fall back naturally; the sub-panel segment forces
  #     accent for its character range. AccentPale = home-accent at 55%
  #     mixed with --color-bg, giving a "soft brand-family" feel that
  #     stays distinct from AppVersion's muted gray.
  #
  # Why the screen prefix was dropped (regression from Phase 2D):
  #   The breadcrumb now represents PANEL state. The screen name is
  #   already shown by the top-status-bar ScreensList component, so
  #   repeating it in the breadcrumb is redundant. The screen name is
  #   only retained as the IDLE fallback so the breadcrumb is never
  #   visually empty before the user focuses a panel.
  #
  # Format (mirrored 1:1 in tui_breadcrumb_controller.js):
  #   - format(nil, nil)              → ""        (used only by callers
  #                                                that pass the panel
  #                                                state explicitly; the
  #                                                instance method uses
  #                                                the screen name as
  #                                                idle fallback instead)
  #   - format("security", nil)       → "security"
  #   - format("security", "totp")    → "security:(totp)"
  #
  # Constructor inputs:
  #   - screen:    required string ("home", "videos", "games", ...). Used
  #                ONLY for the idle render (no panel focused).
  #   - panel:     optional string. When present, becomes the headline.
  #   - sub_panel: optional string. Only renders alongside panel.
  #
  # The component honors the `data-tui-status-bar-target="section"`
  # contract so `tui_status_bar_controller.js`'s seedSectionFromFocusedPanel
  # + handlePanelFocus keep working unchanged.
  #
  # @contract see app/components/tui/transitionable.rb
  # @contract see app/javascript/controllers/tui_transition_controller.js
  # @contract see app/javascript/controllers/tui_breadcrumb_controller.js
  class BreadcrumbComponent < ViewComponent::Base
    include Tui::Transitionable

    def initialize(screen:, panel: nil, sub_panel: nil)
      @screen = screen.to_s
      @panel = panel.presence&.to_s
      @sub_panel = sub_panel.presence&.to_s
    end

    attr_reader :screen, :panel, :sub_panel

    # Mirror of the JS formatter in tui_breadcrumb_controller.js#format.
    # Kept here as a class method so specs + Ruby callers can derive the
    # same string the Stimulus controller will compute client-side.
    #
    # Note: this DROPS the screen prefix. The instance method
    # `current_value` uses the screen name as the idle fallback when
    # `@panel` is blank — that's the only place the screen name appears.
    def self.format(panel, sub_panel)
      panel = panel.to_s if panel
      sub_panel = sub_panel.to_s if sub_panel
      return "" if panel.nil? || panel.empty?
      return panel if sub_panel.nil? || sub_panel.empty?

      "#{panel}:(#{sub_panel})"
    end

    # Three-state value:
    #   - no panel focused  → screen name (idle fallback)
    #   - panel only        → "<panel>"
    #   - panel + sub-panel → "<panel>:(<sub-panel>)"
    def current_value
      return @screen if @panel.nil? || @panel.empty?

      self.class.format(@panel, @sub_panel)
    end

    # Host color:
    #   - no panel focused → :"accent-pale" (idle)
    #   - panel only       → :accent
    #   - panel + sub-panel → :"accent-pale" (segments override the
    #     sub-panel range to accent; the un-segmented ":(" and ")"
    #     delimiters inherit the host accent-pale color)
    #
    # The symbol uses a dash so `.to_s` produces "accent-pale" — matching
    # the dash-case key in tui_transition_controller.js COLOR_CLASS.
    # (The Transitionable mixin emits color via `color.to_s` with no
    # underscore→dash conversion, so dash-in-symbol is the canonical
    # cross-language wire shape.)
    def color_for_state
      return :"accent-pale" if @panel.nil? || @panel.empty?
      return :"accent-pale" if @sub_panel.present?

      :accent
    end

    # Segments descriptor consumed by `tui-transition`'s segmentsValue.
    # Only emitted in the panel + sub-panel state; idle + panel-only
    # rely on the host color alone.
    #
    # Each entry: { name, range: [start, endExclusive], color: <name> }.
    # The closing ")" and the opening ":(" delimiters are intentionally
    # NOT in any segment — they inherit the host accent-pale color, which
    # is exactly what we want (soft brand-family for the whole non-active
    # range, with accent reserved for the focused sub-panel).
    def segments_json
      return "" if @panel.nil? || @panel.empty?
      return "" if @sub_panel.nil? || @sub_panel.empty?

      panel_start = 0
      panel_end = @panel.length             # exclusive
      sub_start = panel_end + 2             # +2 for the ":(" delimiter
      sub_end = sub_start + @sub_panel.length
      [
        { name: "panel_title",     range: [ panel_start, panel_end ], color: "accent-pale" },
        { name: "sub_panel_title", range: [ sub_start,   sub_end   ], color: "accent" }
      ].to_json
    end

    def transitionable_data
      attrs = transitionable_attrs(value: current_value, color: color_for_state)
      segments = segments_json
      attrs[:data][:tui_transition_segments_value] = segments unless segments.empty?
      attrs
    end
  end
end
