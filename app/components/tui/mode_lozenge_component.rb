module Tui
  # Beta 4 — Phase F1. Mode lozenge for the bottom status bar.
  # Renders the current editor mode as a styled span, vim-style.
  #
  # Kwargs:
  #   mode: (Symbol) — :normal, :command, or :search. Defaults to :normal
  #                    for any unrecognised value.
  #
  # Variants: CSS modifier `.bsb-mode--<mode>` on the root span drives the
  # accent color (cyan for normal, purple for command, green for search)
  # via `app/assets/tailwind/application.css`.
  #
  # i18n: label text comes from `tui.bst.mode.<mode>` (en.yml).
  class ModeLozengeComponent < ViewComponent::Base
    MODES = %i[normal command search].freeze

    # @param mode [Symbol] current editor mode — :normal, :command, :search
    def initialize(mode: :normal)
      @mode = MODES.include?(mode.to_sym) ? mode.to_sym : :normal
    end

    attr_reader :mode

    def mode_label
      t("tui.bst.mode.#{mode}")
    end
  end
end
