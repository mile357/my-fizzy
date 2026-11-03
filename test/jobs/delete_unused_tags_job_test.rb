require "test_helper"

class DeleteUnusedTagsJobTest < ActiveJob::TestCase
  test "deletes tags that are not used by any cards" do
    unused = Tag.create!(title: "unused")

    assert_changes -> { Tag.count }, -1 do
      DeleteUnusedTagsJob.perform_now
    end

    assert_not Tag.exists?(unused.id), "Unused tag should be deleted"
  end

  test "preserves tags scheduled as initiatives even if they have no cards" do
    initiative = Tag.create!(title: "scheduled-roadmap", start_date: Date.current, end_date: Date.current + 1.month)

    assert_no_changes -> { Tag.count } do
      DeleteUnusedTagsJob.perform_now
    end

    assert Tag.exists?(initiative.id), "Initiative tag should be preserved even without cards"
  end

  test "preserves unscheduled tags that have milestones even if they have no cards" do
    tag_with_milestone = Tag.create!(title: "unscheduled-roadmap")
    tag_with_milestone.checkpoints.create!(content: "Phase 1")

    assert_no_changes -> { Tag.count } do
      DeleteUnusedTagsJob.perform_now
    end

    assert Tag.exists?(tag_with_milestone.id), "Tag with milestones should be preserved even when unscheduled"
  end
end
