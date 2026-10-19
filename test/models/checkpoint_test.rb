require "test_helper"

class CheckpointTest < ActiveSupport::TestCase
  setup do
    @tag = Tag.create!(title: "test-tag")
  end

  test "validates presence of content" do
    checkpoint = @tag.checkpoints.build(content: "")
    assert_not checkpoint.valid?
    assert_includes checkpoint.errors[:content], "can't be blank"
  end

  test "toggle! switches completion status" do
    checkpoint = @tag.checkpoints.create!(content: "Test milestone", completed: false)
    assert_not checkpoint.completed?
    assert_nil checkpoint.completed_at

    checkpoint.toggle!
    assert checkpoint.completed?
    assert_not_nil checkpoint.completed_at

    checkpoint.toggle!
    assert_not checkpoint.completed?
    assert_nil checkpoint.completed_at
  end

  test "toggle switches completion status without bang" do
    checkpoint = @tag.checkpoints.create!(content: "Non-bang milestone", completed: false)
    assert_not checkpoint.completed?

    checkpoint.toggle
    assert checkpoint.completed?
    assert_not_nil checkpoint.completed_at
  end
end
