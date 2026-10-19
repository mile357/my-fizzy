# frozen_string_literal: true

require "test_helper"

class InitiativesHelperTest < ActionView::TestCase
  test "packs non-overlapping initiatives with a 1-day gap onto the same line" do
    init1 = Tag.new(title: "first", start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 15))
    init2 = Tag.new(title: "second", start_date: Date.new(2026, 10, 16), end_date: Date.new(2026, 10, 31))

    lanes = pack_initiatives_into_lanes([ init1, init2 ])

    assert_equal 1, lanes.size, "Non-overlapping initiatives with a 1-day gap should share the same lane"
    assert_equal 2, lanes[0][:items].size
    assert_equal "first", lanes[0][:items][0][:initiative].title
    assert_equal "second", lanes[0][:items][1][:initiative].title
  end

  test "places overlapping initiatives on separate lines" do
    init1 = Tag.new(title: "overlap-1", start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 20))
    init2 = Tag.new(title: "overlap-2", start_date: Date.new(2026, 10, 15), end_date: Date.new(2026, 10, 31))

    lanes = pack_initiatives_into_lanes([ init1, init2 ])

    assert_equal 2, lanes.size, "Overlapping initiatives must be on separate lanes"
    assert_equal 1, lanes[0][:items].size
    assert_equal 1, lanes[1][:items].size
  end

  test "places initiatives starting on the same day as previous end date on separate lines" do
    init1 = Tag.new(title: "same-day-end", start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 15))
    init2 = Tag.new(title: "same-day-start", start_date: Date.new(2026, 10, 15), end_date: Date.new(2026, 10, 31))

    lanes = pack_initiatives_into_lanes([ init1, init2 ])

    assert_equal 2, lanes.size, "Initiatives sharing an active day must be on separate lanes"
  end

  test "minimizes vertical space aggressively with multiple initiatives" do
    # Lane 0: Jan 1-31, Mar 1-31, May 1-31
    # Lane 1: Jan 15-Feb 15, Apr 1-30
    i1 = Tag.new(title: "jan", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31))
    i2 = Tag.new(title: "jan-feb", start_date: Date.new(2026, 1, 15), end_date: Date.new(2026, 2, 15))
    i3 = Tag.new(title: "mar", start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 3, 31))
    i4 = Tag.new(title: "apr", start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 30))
    i5 = Tag.new(title: "may", start_date: Date.new(2026, 5, 1), end_date: Date.new(2026, 5, 31))

    lanes = pack_initiatives_into_lanes([ i5, i2, i4, i1, i3 ])

    assert_equal 2, lanes.size, "Expected 5 initiatives to pack into exactly 2 lines"
    assert_equal [ "jan", "mar", "apr", "may" ], lanes[0][:items].map { |it| it[:initiative].title }
    assert_equal [ "jan-feb" ], lanes[1][:items].map { |it| it[:initiative].title }
  end

  test "handles empty initiatives list" do
    assert_equal [], pack_initiatives_into_lanes([])
  end
end
