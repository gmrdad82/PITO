module Tui
  # Beta 4 — Phase F2. TUI checkbox primitive. Renders `[ ]` / `[x]` / `[-]`
  # as the universal selection / toggle marker — per ADR 0016's
  # destructive action pattern: `[x]` selects rows + confirmation
  # dialog confirms + cable removes. ONE pattern for every
  # destructive flow.
  #
  # Three render modes, picked by the constructor args:
  #
  #   * `href:` given        -> renders as `<a>` (URL-param toggle, used
  #                             by `FilterChipComponent` and similar).
  #   * `name:` given (no href)
  #                           -> renders as `<label>` wrapping a hidden
  #                              `name=no` input + the visible checkbox,
  #                              guaranteeing the form post always
  #                              receives `yes` or `no` (per pito's hard
  #                              rule: "yes / no for external booleans").
  #   * neither given        -> renders as inert `<span>` (display-only
  #                             marker — e.g. row selection state
  #                             rendered server-side without a form).
  #
  # The label argument is optional — bare `[x]` is fine for tight cells.
  # When provided, it renders after the box with one leading space, so
  # the rendered glyph is `[x] label` (the character grid stays
  # predictable).
  #
  # ## Three-state glyphs
  #
  # | State          | Kwarg                    | Glyph | Color                          |
  # |----------------|--------------------------|-------|--------------------------------|
  # | unchecked      | checked: false (default) | [ ]   | section accent (action slot)   |
  # | checked        | checked: true            | [x]   | section accent (action slot)   |
  # | indeterminate  | indeterminate: true      | [-]   | muted (var(--color-muted))     |
  #
  # `indeterminate: true` overrides `checked:` — the `[-]` glyph always
  # wins regardless of the `checked` value. This matches the parent-panel
  # "mixed sub-panel flags" semantic used by Tui::SyncIndicatorComponent.
  #
  # ## Variants
  #
  #   indeterminate: false (default) — standard 2-state checkbox
  #   indeterminate: true            — 3rd state; renders `[-]` in muted
  #
  # ## Focusables
  #
  #   Not directly focusable. Housed inside a focusable action button or
  #   link by the parent component.
  #
  # ## Related
  #
  #   Tui::SyncIndicatorComponent — uses the same 3-state glyph vocabulary
  #   (inline, not via this component, to keep render cost low).
  class CheckboxComponent < ViewComponent::Base
    def initialize(label: nil, checked: false, indeterminate: false, name: nil, value: "yes", href: nil)
      @label = label
      @checked = !!checked
      @indeterminate = !!indeterminate
      @name = name
      @value = value
      @href = href
    end

    attr_reader :label, :checked, :name, :value, :href

    def indeterminate?
      @indeterminate
    end

    def glyph
      if indeterminate?
        "-"
      elsif checked
        "x"
      else
        " "
      end
    end

    def renders_as_link?
      !href.nil?
    end

    def renders_as_form_input?
      !name.nil? && href.nil?
    end
  end
end
