module Tui
  # Beta 4 — Phase F1. `: command` hint for the bottom status bar right side.
  # Static UI — no kwargs. Renders the `:` key glyph in foreground weight
  # followed by the `command` label in muted styling.
  #
  # i18n: key glyph from `tui.bst.command_key`, label from `tui.bst.command_label`.
  class CommandHintComponent < ViewComponent::Base
    def command_key
      t("tui.bst.command_key")
    end

    def command_label
      t("tui.bst.command_label")
    end
  end
end
