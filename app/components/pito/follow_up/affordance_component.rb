# frozen_string_literal: true

module Pito
  module FollowUp
    # Renders the reply affordance for a follow-up-able message.
    #
    # Shows the hashtag reply hint: `#<handle> <usage>` — e.g.
    # `#delta-4823 preview <name> · apply <name>`.
    #
    # Renders NOTHING when the event is consumed (`reply_consumed: true`):
    # the affordance must be invisible once the user has already replied.
    #
    # Usage (from within an event component or partial):
    #
    #   <%= render Pito::FollowUp::AffordanceComponent.new(
    #     handle: payload["reply_handle"],
    #     usage:  t("pito.follow_up.affordance.theme_list"),
    #     consumed: payload["reply_consumed"]
    #   ) %>
    #
    # @param handle   [String]  the unique hashtag (without the `#` prefix).
    # @param usage    [String]  human-readable action hint shown after the hashtag.
    # @param consumed [Boolean] when truthy, the component renders nothing.
    class AffordanceComponent < ViewComponent::Base
      def initialize(handle:, usage:, consumed: false)
        @handle   = handle.to_s
        @usage    = usage.to_s
        @consumed = consumed == true || consumed == "true"
      end

      def render?
        @handle.present? && !@consumed
      end

      attr_reader :handle, :usage
    end
  end
end
