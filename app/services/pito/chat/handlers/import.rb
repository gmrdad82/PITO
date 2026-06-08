# frozen_string_literal: true

# Fallback handler for the bare `import` chat verb.
#
# The real action — opening the IGDB import sidebar — is intercepted by the
# ChatController fast-path when the user types `import game[s] [title]`.
# This handler is only reached for unmatched / bare `import` input, and
# returns a usage hint pointing at `import game <title>`.
module Pito
  module Chat
    module Handlers
      class Import < Pito::Chat::Handler
        self.verb = :import
        self.description_key = "pito.chat.import.descriptions.import"

        def call
          Pito::Chat::Result::Error.new(
            message_key: "pito.chat.import.usage_hint",
            message_args: {}
          )
        end
      end
    end
  end
end
