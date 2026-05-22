module Tui
  # Phase 1C (2026-05-22) — minimum-window-size guard dialog.
  #
  # Pattern parity with `Tui::AlertDialogComponent` (message-only, no
  # submit action). Built on the canonical `.tui-dialog-frame` chrome
  # via `Tui::DialogComponent`, so the title-in-border + `[Esc] to
  # close` affordance stays uniform across every dialog in the app.
  #
  # Mounted once in the application layout. The `tui-size-guard`
  # Stimulus controller (mounted on the dialog element itself) listens
  # for `resize` events on `window` and calls `showModal()` /
  # `close()` as the viewport crosses the locked minimum:
  #
  #   * MIN_WIDTH_PX  = 1280 (half of a 2560-wide 1440p display)
  #   * MIN_HEIGHT_PX =  800
  #
  # `[Esc]` dismisses the dialog locally, but the controller re-opens
  # it on the next resize check if the window is still below the
  # minimum, so a too-small window cannot escape the guard.
  #
  # The title + message both flow through i18n (`tui.size_guard.*`)
  # so the future Rust TUI client can share the same copy.
  class SizeGuardDialogComponent < ViewComponent::Base
    DIALOG_ID = "size-guard-dialog".freeze
    MIN_WIDTH_PX = 1280
    MIN_HEIGHT_PX = 800

    def title
      I18n.t("tui.size_guard.title")
    end

    def message
      I18n.t("tui.size_guard.message", min_width: MIN_WIDTH_PX, min_height: MIN_HEIGHT_PX)
    end
  end
end
