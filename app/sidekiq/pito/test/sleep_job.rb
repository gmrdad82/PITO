# FB-test-infra (2026-05-22). Dummy sleep job. Enqueue from a rake
# task (`rake pito:test:enqueue_sleep_job[5]`) to put one worker into
# the Sidekiq busy queue for `seconds` seconds — exercises the
# `b<n>` cell on the top status bar (and any future Sidekiq panel
# cable consumers) live.
#
# Purpose: TEST INFRA ONLY. Not wired into sidekiq-cron, not invoked
# by domain code. Retry is disabled so a kill / boot loss doesn't
# leave a phantom in the retry queue. Always pair with the matching
# `FailingJob` (retry queue) + `ScheduledJob` (scheduled set) when
# you want to populate all three Sidekiq buckets at once.
module Pito
  module Test
    class SleepJob
      include Sidekiq::Job
      sidekiq_options queue: :default, retry: 0

      def perform(seconds = 5)
        sleep seconds
      end
    end
  end
end
