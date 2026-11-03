require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "downcase title" do
    assert_equal "a tag", Tag.create!(title: "A TAG").title
  end

  test ".unused returns tags not associated with any cards" do
    unused = Tag.create!(title: "unused")

    unused_tags = Tag.unused

    assert_includes unused_tags, unused
    assert_not_includes unused_tags, tags(:web)
    assert_not_includes unused_tags, tags(:mobile)
  end

  test ".unused returns empty relation if all tags are used" do
    assert_empty Tag.unused
  end

  test "initiative detection and progress percentage are driven strictly by milestones" do
    tag = Tag.create!(title: "q4-deliverables", start_date: 2.weeks.ago, end_date: 1.week.ago)
    assert tag.initiative?
    assert_equal 0, tag.progress_percentage
    assert_not tag.completed?
    assert tag.overdue?

    # Even with a closed card attached, 0 milestones means 0% and not completed
    card = cards(:logo)
    Tagging.create!(account: tag.account, tag: tag, card: card)
    assert_equal 0, tag.reload.progress_percentage
    assert_not tag.completed?

    cp1 = tag.checkpoints.create!(content: "Deliverable 1", completed: true)
    cp2 = tag.checkpoints.create!(content: "Deliverable 2", completed: false)

    assert_equal 50, tag.progress_percentage
    assert_not tag.completed?
    assert tag.overdue?

    cp2.toggle!
    assert_equal 100, tag.progress_percentage
    assert tag.completed?
    assert_not tag.overdue?
  end

  test "previous_due_dates extracts earlier deadlines from initiative history" do
    tag = Tag.create!(title: "release-roadmap", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
    user = users(:kevin)

    assert_empty tag.previous_due_dates

    # Simulate extension from June 30 to Sept 30
    InitiativeActivity.track(
      tag,
      action: "dates_changed",
      description: "Changed target date to Sep 30, 2026",
      particulars: { old_end_date: "2026-06-30", end_date: "2026-09-30" },
      creator: user
    )
    tag.update!(end_date: Date.new(2026, 9, 30))

    assert_equal [ Date.new(2026, 6, 30) ], tag.reload.previous_due_dates

    # Simulate second extension from Sept 30 to Dec 31
    InitiativeActivity.track(
      tag,
      action: "dates_changed",
      description: "Changed target date to Dec 31, 2026",
      particulars: { old_end_date: "2026-09-30", end_date: "2026-12-31" },
      creator: user
    )
    tag.update!(end_date: Date.new(2026, 12, 31))

    assert_equal [ Date.new(2026, 6, 30), Date.new(2026, 9, 30) ], tag.reload.previous_due_dates
  end

  test "previous_due_dates parses text description even when another activity has structured particulars" do
    tag = Tag.create!(title: "legacy-roadmap", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 8, 31))
    user = users(:kevin)

    InitiativeActivity.track(
      tag,
      action: "dates_changed",
      description: "Changed dates to Jan 01, 2026 – May 15, 2026",
      particulars: {},
      creator: user
    )
    InitiativeActivity.track(
      tag,
      action: "dates_changed",
      description: "Changed target date to Aug 31, 2026",
      particulars: { old_end_date: "2026-07-01", end_date: "2026-08-31" },
      creator: user
    )

    assert_equal [ Date.new(2026, 5, 15), Date.new(2026, 7, 1) ], tag.reload.previous_due_dates
  end

  test "new_tag_ids returns tags created in the past day" do
    old_tag = Tag.create!(title: "older-tag", created_at: 3.days.ago)
    new_tag = Tag.create!(title: "brand-new-tag", created_at: 2.hours.ago)

    new_ids = Tag.new_tag_ids(old_tag.account)
    assert_includes new_ids, new_tag.id
    assert_not_includes new_ids, old_tag.id
  end

  test "recent_tag_ids returns tags created or used in the past month" do
    old_tag = Tag.create!(title: "ancient-tag", created_at: 6.months.ago, updated_at: 6.months.ago)
    recent_tag = Tag.create!(title: "month-old-tag", created_at: 2.weeks.ago)

    recent_ids = Tag.recent_tag_ids(old_tag.account)
    assert_includes recent_ids, recent_tag.id
    assert_not_includes recent_ids, old_tag.id

    # If old tag is used on a card created in the past month, it becomes recent
    card = cards(:logo)
    Tagging.create!(account: old_tag.account, tag: old_tag, card: card, created_at: 1.week.ago)

    recent_ids_after = Tag.recent_tag_ids(old_tag.account)
    assert_includes recent_ids_after, old_tag.id
  end

  test "validates title presence and length" do
    tag = Tag.new(title: "")
    assert_not tag.valid?
    assert_includes tag.errors[:title], "can't be blank"

    too_long = Tag.new(title: "a" * 101)
    assert_not too_long.valid?
    assert_includes too_long.errors[:title], "is too long (maximum is 100 characters)"
  end

  test "validates color format and clears color when unscheduled" do
    valid_tag = Tag.create!(title: "valid-color", start_date: Date.current, end_date: Date.current + 1.week, color: "#3b82f6")
    assert_equal "#3b82f6", valid_tag.color

    valid_tag.update!(start_date: nil, end_date: nil)
    assert_nil valid_tag.reload.color

    invalid_tag = Tag.new(title: "invalid-color", color: "blue; background: red;")
    assert_not invalid_tag.valid?
    assert_includes invalid_tag.errors[:color], "is invalid"
  end

  test "validates end date cannot precede start date" do
    tag = Tag.new(title: "invalid-dates", start_date: Date.current, end_date: 1.week.ago)
    assert_not tag.valid?
    assert_includes tag.errors[:end_date], "cannot precede start date"
  end

  test "contrast_text_color returns dark text for light colors and white for dark colors" do
    light_tag = Tag.new(title: "bright-yellow", color: "#ffff00")
    assert_equal "#0f172a", light_tag.contrast_text_color

    light_3digit_tag = Tag.new(title: "bright-yellow-3", color: "#ff0")
    assert_equal "#0f172a", light_3digit_tag.contrast_text_color

    white_tag = Tag.new(title: "pure-white", color: "#fff")
    assert_equal "#0f172a", white_tag.contrast_text_color

    dark_tag = Tag.new(title: "dark-blue", color: "#1e3a8a")
    assert_equal "#ffffff", dark_tag.contrast_text_color

    dark_3digit_tag = Tag.new(title: "pure-black", color: "#000")
    assert_equal "#ffffff", dark_3digit_tag.contrast_text_color
  end

  test "unused scope excludes tags scheduled as initiatives or having checkpoints" do
    unused_regular = Tag.create!(title: "purely-unused")
    scheduled_init = Tag.create!(title: "scheduled-no-cards", start_date: Date.current, end_date: Date.current + 2.weeks)
    unscheduled_with_checkpoint = Tag.create!(title: "unscheduled-with-milestone")
    unscheduled_with_checkpoint.checkpoints.create!(content: "Keep me")

    assert_includes Tag.unused, unused_regular
    assert_not_includes Tag.unused, scheduled_init
    assert_not_includes Tag.unused, unscheduled_with_checkpoint
  end
end
