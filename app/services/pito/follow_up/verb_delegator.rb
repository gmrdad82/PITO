# frozen_string_literal: true

module Pito
  module FollowUp
    # Delegates a `#<handle> <verb> <rest>` reply to the SAME chat verb handler
    # that serves `<verb> <rest>` in free chat (Phase 18, T18.4).
    #
    # A follow-up handler (game_list, game_detail, …) becomes a thin shim: it
    # passes the live source event + the reply's `rest` here. We reconstruct the
    # chat invocation, run it through `Chat::Dispatcher` with a `FollowUpContext`
    # attached (so resolution can scope to the source list's rows or read the
    # source card's entity — T18.2), then adapt the chat result into a follow-up
    # result (T18.3). One code path builds + sends; no duplication.
    #
    #   VerbDelegator.call(source_event: ev, rest: "show 5", conversation: c)
    #   # → runs Chat::Handlers::Show with follow_up context → FollowUp::Result::Append
    module VerbDelegator
      module_function

      # @param source_event [Event]        the live event being replied to.
      # @param rest         [String]       text after `#<handle> ` (e.g. "show 5", "rm").
      # @param conversation [Conversation]
      # @param channel      [String, nil]  shift+tab channel scope, if any.
      # @return [Pito::FollowUp::Result::Append, Pito::FollowUp::Result::Error]
      def call(source_event:, rest:, conversation:, channel: nil)
        input = rest.to_s.strip
        args  = input.sub(/\A\S+\s*/, "") # everything after the verb word

        context = Pito::Chat::FollowUpContext.new(source_event:, rest: args)
        result  = Pito::Chat::Dispatcher.call(
          input:        input,
          conversation: conversation,
          channel:      channel,
          follow_up:    context
        )

        Pito::FollowUp::ChatResultAdapter.call(result)
      end
    end
  end
end
