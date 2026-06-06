# frozen_string_literal: true

module Pito
  # Generates a short, human-readable handle like "alpha-1322" for use in
  # follow-up-able events and (legacy) confirmation events.
  #
  # Uniqueness is now checked across ALL events that carry a `reply_handle`
  # payload field (including consumed ones — consumed handles are still
  # reserved so the generator never re-picks them).  During the P13→P14
  # transition, confirmation events still use the old `confirmation_handle`
  # field; to prevent accidental collisions we also scan that field as well.
  #
  # Format: "<greek-word>-<4-digit-number>" e.g. "delta-4823".
  # Fallback: SecureRandom.hex(4) when 10 attempts all collide.
  #
  # Usage:
  #   handle = Pito::HandleGenerator.call(conversation)
  #   # → "gamma-5912"
  module HandleGenerator
    GREEK_WORDS = %w[
      alpha beta gamma delta epsilon zeta eta theta
      iota kappa lambda mu nu xi omicron pi rho sigma
      tau upsilon phi chi psi omega
    ].freeze

    module_function

    def call(conversation)
      10.times do
        candidate = "#{GREEK_WORDS.sample}-#{rand(1000..9999)}"
        next if taken?(conversation, candidate)
        return candidate
      end
      SecureRandom.hex(4)
    end

    # Returns true when the candidate is already in use in this conversation,
    # either as a `reply_handle` (new follow-up engine, any kind, any state)
    # or as a legacy `confirmation_handle` (P13→P14 transition window).
    def taken?(conversation, candidate)
      conversation.events
        .where("payload->>'reply_handle' = ?", candidate)
        .exists? ||
        conversation.events
          .where(kind: "confirmation")
          .where("payload->>'confirmation_handle' = ?", candidate)
          .exists?
    end
  end
end
