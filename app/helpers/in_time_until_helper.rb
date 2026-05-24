module InTimeUntilHelper
  # Compact future-relative time string ("in 5d", "in 2w").
  # Delegates to `Pito::Formatter::InTimeUntil` — see that module for
  # full rules and examples. Sibling of `compact_time_ago` (past).
  def in_time_until(value)
    Pito::Formatter::InTimeUntil.call(value)
  end
end
