module Tui
  # Beta 4 — Phase F1. Screens navigation list for the bottom status bar.
  # Renders the `home / videos / games` row with the current screen
  # highlighted via the section-accent cascade.
  #
  # Kwargs:
  #   current_section: (String) — "home", "videos", or "games". Controls
  #                    which entry receives `.bsb-section--current` so the
  #                    `body[data-section]` CSS cascade can apply the right
  #                    accent color without a per-render color lookup.
  #
  # Behavior:
  #   Each screen entry is an `<a>` tag linking to the screen's root path.
  #   The current screen is marked with `.bsb-section--current` (bold +
  #   section-accent foreground in CSS). Non-current screens are muted.
  #
  # i18n: screen labels come from `tui.bst.screens.<name>` (en.yml).
  class ScreensListComponent < ViewComponent::Base
    SECTIONS = %w[home videos games].freeze

    # @param current_section [String] the active screen slug
    def initialize(current_section:)
      @current_section = current_section.to_s
    end

    attr_reader :current_section

    def sections
      SECTIONS
    end

    def section_classes(section)
      classes = [ "bsb-section" ]
      classes << "bsb-section--current" if section == current_section
      classes.join(" ")
    end

    def section_label(section)
      t("tui.bst.screens.#{section}")
    end

    def section_path(section)
      case section
      when "home"   then "/"
      when "videos" then "/videos"
      when "games"  then "/games"
      else "/"
      end
    end
  end
end
