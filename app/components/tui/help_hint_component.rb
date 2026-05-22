module Tui
  # Beta 4 — Phase F1. `? help` hint for the bottom status bar right side.
  # Static UI — no kwargs. Renders the `?` key glyph in foreground weight
  # followed by the `help` label in muted styling.
  #
  # i18n: key glyph from `tui.bst.help_key`, label from `tui.bst.help_label`.
  class HelpHintComponent < ViewComponent::Base
    def help_key
      t("tui.bst.help_key")
    end

    def help_label
      t("tui.bst.help_label")
    end
  end
end
