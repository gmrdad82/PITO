class Tui::ScrollIndicatorComponent < ViewComponent::Base
  # Tui::ScrollIndicatorComponent — paired ▲/▼ overlay glyphs that appear
  # at the top + bottom edges of a scrollable container when content
  # overflows in that direction.
  #
  # Usage:
  #   <div class="scrollable-host" data-controller="tui-scroll-indicator">
  #     <%= render Tui::ScrollIndicatorComponent.new %>
  #     <div class="scrollable-content">
  #       ... overflowing content ...
  #     </div>
  #   </div>
  #
  # The scrollable host should have `position: relative` (or absolute) and
  # `overflow-y: auto` (hidden scrollbars per project convention). The
  # tui-scroll-indicator Stimulus controller mounts on the host, listens
  # for scroll events, and toggles is-visible on the ▲ / ▼ children.
  def initialize
  end
end
