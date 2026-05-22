# FB-test-infra (2026-05-22). Dummy failing job. Enqueue from a rake
# task (`rake pito:test:enqueue_failing_job`) to populate the Sidekiq
# retry set — the job raises on every attempt, Sidekiq retries it
# `retry: 3` times with exponential back-off, and during the back-off
# window it sits in the retry queue. Exercises the `r<n>` cell on
# the top status bar (and any future Sidekiq panel cable consumers)
# live.
#
# Purpose: TEST INFRA ONLY. Not wired into sidekiq-cron, not invoked
# by domain code. The intentional `raise` is suppressed from
# Sentry-style alerts by the retry/dead-set discipline — these jobs
# die loudly inside the test environment by design.
module Pito
  module Test
    class FailingJob
      include Sidekiq::Job
      sidekiq_options queue: :default, retry: 3

      def perform
        raise "intentional failure for retry queue test"
      end
    end
  end
end
