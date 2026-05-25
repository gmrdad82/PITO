# Beta 4 — Phase F1 Lane A. ActionCable connection auth.
#
# Identifies the cable connection by `current_user` so per-panel
# channels can authorize subscriptions (e.g. `StatusBarChannel`
# rejects unauthenticated subscribers).
#
# Auth path mirrors the HTTP layer (`Sessions::AuthConcern`): the
# signed `:pito_session` cookie carries a session plaintext;
# `Sessions::Authenticator` resolves it to a `Session` record;
# presence of a valid session = authenticated.
#
# Z1 (2026-05-25): User model gone. `find_verified_user` now returns
# the `Session` object itself (not session.user which no longer exists).
# All channels guard on `current_user.present?` — the naming is
# preserved for ActionCable API compatibility; semantically it is
# "current_session". The identifier is a non-nil object = connected.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      result = Sessions::Authenticator.call(request)
      return reject_unauthorized_connection unless result.success?

      # Return the session itself as the cable identity (User is gone).
      # Channels that call `current_user.present?` get a truthy value
      # when authenticated, nil/false when not — same contract as before.
      result.session
    end
  end
end
