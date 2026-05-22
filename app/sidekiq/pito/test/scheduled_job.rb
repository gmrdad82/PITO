# FB-test-infra (2026-05-22). Dummy scheduled job. Enqueue from a
# rake task (`rake pito:test:enqueue_scheduled_job[3600]`) with
# `perform_in(seconds.from_now)` to drop one entry into the Sidekiq
# scheduled set without ever running it. Exercises the `s<n>` cell
# on the top status bar (and any future Sidekiq panel cable
# consumers) live.
#
# Purpose: TEST INFRA ONLY. Not wired into sidekiq-cron, not invoked
# by domain code. `perform` is a no-op so if you ever let it actually
# fire (1-second `perform_in` for example) nothing breaks; the row
# just leaves the scheduled set and briefly hits busy=1.
module Pito
  module Test
    class ScheduledJob
      include Sidekiq::Job
      sidekiq_options queue: :default, retry: 0

      def perform
        # no-op: only purpose is to sit in the scheduled set until its
        # scheduled time, then briefly transit busy on its way to done.
      end
    end
  end
end
