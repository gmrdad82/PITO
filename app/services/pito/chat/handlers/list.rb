# frozen_string_literal: true

# Handler for the `list` chat verb → the game library.
#
# Emits a System message listing every game (title-sorted) with its **ID** as the
# key, so the follow-up affordances (`#<handle> show <id>` / `rm <id>`) key off
# the stable id, not the title. Stamped follow-up-able (`game_list`). Empty
# library returns a witty empty-state. All copy via `Pito::Copy`.
#
# NOTE: `game`/`games` are FILLER words in the grammar, so `list` and
# `list games` parse identically — both land here. Other nouns (`list videos`,
# `list channels`) are not listable yet, so we surface a clear error rather than
# silently returning the games shelf.
#
# Filtering syntax: `list games [upcoming] [<genres>…] [<platforms>…]`
# All parts optional, order-independent. See Pito::Chat::GameListFilter for the
# synonym maps and filter semantics.
module Pito
  module Chat
    module Handlers
      class List < Pito::Chat::Handler
        self.verb = :list
        self.description_key = "pito.chat.list.descriptions.list"

        # Nouns we recognise but can't list yet (only games + channels work today).
        UNSUPPORTED_NOUN = /\bvideos?\b/i

        def call
          return list_channels if message.raw.match?(/\bchannels?\b/i)

          if (noun = message.raw[UNSUPPORTED_NOUN, 0])
            return Pito::Chat::Result::Error.new(
              message_key:  "pito.chat.errors.cannot_list",
              message_args: { noun: noun.downcase }
            )
          end

          filtered = Pito::Chat::GameListFilter.filtered?(message.raw)
          games    = Pito::Chat::GameListFilter.call(message.raw)

          if games.empty?
            return filtered ? games_filter_empty : games_empty
          end

          payload = Pito::MessageBuilder::Game::List.call(games, conversation:)

          Pito::Chat::Result::Ok.new(events: [ { kind: :system, payload: payload } ])
        end

        private

        # `list channels` → inline channel cards rendered by Pito::Channel::ListComponent.
        # Returns a :system event with an html body (intro line + wrapping card strip).
        def list_channels
          channels = ::Channel.order(:title)
          if channels.empty?
            return Pito::Chat::Result::Ok.new(events: [
              { kind: :system, payload: Pito::MessageBuilder::Text.call("pito.copy.channels.list_empty") }
            ])
          end

          payload = Pito::MessageBuilder::Channel::List.call(channels, conversation:)

          Pito::Chat::Result::Ok.new(events: [ { kind: :system, payload: payload } ])
        end

        def games_empty
          Pito::Chat::Result::Ok.new(events: [
            { kind: :system, payload: Pito::MessageBuilder::Text.call("pito.copy.games.list_empty") }
          ])
        end

        def games_filter_empty
          Pito::Chat::Result::Ok.new(events: [
            { kind: :system, payload: Pito::MessageBuilder::Text.call("pito.copy.games.list_filter_empty") }
          ])
        end
      end
    end
  end
end
