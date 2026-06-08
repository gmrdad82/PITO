# frozen_string_literal: true

# Handler for the `publish video <id|title>` chat verb.
#
# LOCAL-ONLY: sets privacy_status: :public and clears publish_at.
# Returns a :system Standard message with witty confirmation copy.
module Pito
  module Chat
    module Handlers
      class Publish < Pito::Chat::Handler
        self.verb = :publish
        self.description_key = "pito.chat.publish.descriptions.publish"

        NOUN_FILLERS = %w[video videos].freeze

        def call
          ref = extract_ref
          return needs_ref if ref.blank?

          video = resolve_video(ref)
          return not_found(ref) unless video

          video.update!(privacy_status: :public, publish_at: nil)

          Pito::Chat::Result::Ok.new(events: [
            { kind: :system, payload: Pito::MessageBuilder::Text.call("pito.copy.videos.published", title: video.title) }
          ])
        end

        private

        def extract_ref
          message.body_tokens
                 .map(&:value)
                 .reject { |w| NOUN_FILLERS.include?(w.to_s.downcase) }
                 .join(" ")
                 .strip
        end

        def resolve_video(ref)
          id = ref.sub(/\A#\s*/, "")
          return ::Video.find_by(id: id) if id.match?(/\A\d+\z/)

          ::Video.find_by("title ILIKE ?", ref)
        end

        def needs_ref
          Pito::Chat::Result::Error.new(message_key: "pito.chat.publish.needs_ref", message_args: {})
        end

        def not_found(ref)
          Pito::Chat::Result::Ok.new(events: [
            { kind: :system, payload: Pito::MessageBuilder::Text.call("pito.copy.videos.not_found", ref: ref) }
          ])
        end
      end
    end
  end
end
