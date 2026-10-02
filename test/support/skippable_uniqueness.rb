# Test helper (REQ-006): lets a test simulate a unique-index race. While the flag is set, the Rails-level uniqueness
# validation is skipped, so only the database unique index can answer (ActiveRecord::RecordNotUnique).
# Load it explicitly with `require_relative` from every test that uses it; it is inert unless the flag is set.
module SkippableUniqueness
  FLAG = :skip_uniqueness_validation

  def validate_each(record, attribute, value)
    return if Thread.current[FLAG]

    super
  end

  # Runs the block with the uniqueness validation skipped (always restores the flag).
  def self.skipping
    previous = Thread.current[FLAG]
    Thread.current[FLAG] = true
    yield
  ensure
    Thread.current[FLAG] = previous
  end
end

ActiveRecord::Validations::UniquenessValidator.prepend(SkippableUniqueness) unless ActiveRecord::Validations::UniquenessValidator.include?(SkippableUniqueness)
