module Tui
  # Beta 4 — Phase D9 (2026-05-22). About dialog. Replaces the legacy
  # `AboutModalComponent` with a wrapper around the canonical
  # `Tui::DialogComponent` chrome.
  #
  # Renders the app identity card (name, version, license, source, commit,
  # contact) as a centered KV stack. Every clickable surface (version,
  # license link, source link, commit link) flows through
  # `BracketedLinkComponent` so the bracketed-action grammar holds.
  #
  # Opened via `?` flat-key indirectly through the leader menu, or via the
  # `:about` command in the command palette (per
  # `Tui::CommandRegistry::GLOBAL_COMMANDS`). Closed via `[Esc]` per the
  # canonical dialog chrome contract.
  #
  # Mounted in `app/views/layouts/application.html.erb` once per page so
  # every screen shares the same dialog node. The dialog id is hard-locked
  # to `about-dialog`; the command palette's `open_about` action targets
  # this id.
  class AboutDialogComponent < ViewComponent::Base
    include ApplicationHelper

    DIALOG_ID = "about-dialog".freeze
    REPO_SLUG = "gmrdad82/pito".freeze

    # FB-ITEM-3 (2026-05-22). `v` glyph sourced from `tui.about.version_prefix`
    # so the About dialog has zero hardcoded English. The TUI client reads
    # the same locale file when it derives its About screen.
    def version_string
      "#{I18n.t('tui.about.version_prefix')}#{app_version}"
    end

    def version_url
      "https://github.com/#{REPO_SLUG}/releases/tag/#{version_string}"
    end

    def license_url
      "https://github.com/#{REPO_SLUG}/blob/main/LICENSE"
    end

    def source_url
      "https://github.com/#{REPO_SLUG}"
    end

    # FB-128 (2026-05-21). GitHub commit URL for the running process,
    # surfaced as a bracketed `[<short-sha>]` action in the commit row.
    # Returns `nil` when `Pito::GitRevision` could not capture a SHA at
    # boot (production container without `.git/`, etc.) — the template
    # falls back to plain unlinked text in that case.
    def commit_url
      Pito::GitRevision.commit_url
    end

    def commit_short_sha
      Pito::GitRevision.short_sha
    end

    # Mirrors the footer copy in `layouts/application.html.erb` so the two
    # surfaces stay in lockstep. `Date.current.year` matches the footer's
    # dynamic year. Copy is interpolated through `tui.about.copyright`.
    def copyright_text
      I18n.t("tui.about.copyright", year: Date.current.year)
    end

    def env
      Rails.env
    end
  end
end
