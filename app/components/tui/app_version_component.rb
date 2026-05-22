module Tui
  # Beta 4 — extracted from `Tui::TopStatusBarComponent` (2026-05-22) per
  # "ViewComponents are kings" — the leading version label of the top
  # status bar is now its own VC.
  #
  # Renders the literal `VERSION` file contents as a link to the matching
  # GitHub release tag (`https://github.com/gmrdad82/pito/releases/tag/v<VERSION>`).
  # `target=_blank` + `rel=noopener noreferrer` so the release page opens
  # in a new tab without leaking opener context.
  #
  # No constructor arguments — the version is read from
  # `Rails.root.join("VERSION")` lazily so test runs don't pay the
  # filesystem hit until the component actually renders. Memoization is
  # per-instance (mirrors the `ApplicationHelper#app_version` shape so
  # the SSR + helper paths agree on the same string).
  #
  # The `release_url` template lives in `config/locales/tui/en.yml` under
  # `tui.tst.version.release_url` so the GitHub owner/repo slug isn't
  # hardcoded in component source — same i18n discipline as every other
  # tui surface.
  class AppVersionComponent < ViewComponent::Base
    def version
      @version ||= Rails.root.join("VERSION").read.strip
    end

    def release_url
      I18n.t("tui.tst.version.release_url", version: version)
    end
  end
end
