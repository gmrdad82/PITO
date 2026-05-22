# FB-test-infra (2026-05-22). Dev/test cable-broadcast trampoline.
# Backs `window.Pito.testBroadcast(kind, payload)` so a developer can
# poke a cable-driven ViewComponent live from the browser console
# without leaving the running tab. The endpoint is mounted in
# `config/routes.rb` ONLY for `Rails.env.development?` /
# `Rails.env.test?`, but we re-check inside `development_only!` as
# defense-in-depth — if someone mistakenly drops the route guard or
# a future env (CI staging?) inherits the mount, the controller still
# refuses to broadcast in production.
#
# `allow_anonymous` is fine here because the route only exists in
# environments the user owns end-to-end (their laptop, the test
# suite). The broadcast payload still flows through
# `Pito::CableBroadcaster.broadcast_status_bar`, which enforces the
# canonical envelope shape — the controller is a thin adapter.
class TestBroadcastController < ApplicationController
  # The dev/test trampoline is called from the browser console fetch
  # (which sends the CSRF header) AND from request specs (which set
  # `allow_forgery_protection = false` env-wide). Some Turbo / JS
  # paths still trip the per-controller CSRF check in test env (the
  # global flag does not always disable the per-action gate when the
  # controller subclasses `ActionController::Base` with
  # `protect_from_forgery` implicit). Skip explicitly here — the
  # endpoint is already env-gated below.
  skip_forgery_protection

  allow_anonymous :create

  before_action :development_or_test_only!

  def create
    Pito::CableBroadcaster.broadcast_status_bar(
      params.fetch(:payload).to_unsafe_h,
      kind: params.fetch(:kind).to_s
    )
    head :no_content
  end

  private

  def development_or_test_only!
    return if Rails.env.development? || Rails.env.test?
    head :forbidden
  end
end
