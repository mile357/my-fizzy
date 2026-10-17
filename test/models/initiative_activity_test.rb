require "test_helper"

class InitiativeActivityTest < ActiveSupport::TestCase
  setup do
    @tag = tags(:web)
    @user = users(:kevin)
  end

  test "track records activity" do
    assert_difference -> { InitiativeActivity.count } => 1 do
      activity = InitiativeActivity.track(
        @tag,
        action: "dates_changed",
        description: "Changed target date to Dec 31, 2026",
        creator: @user
      )

      assert_equal @tag.account, activity.account
      assert_equal @tag, activity.tag
      assert_equal @user, activity.creator
      assert_equal "dates_changed", activity.action
      assert_equal "Changed target date to Dec 31, 2026", activity.description
    end
  end

  test "track ignores non-persisted tags" do
    new_tag = Tag.new(title: "unsaved")
    assert_no_difference -> { InitiativeActivity.count } do
      InitiativeActivity.track(new_tag, action: "test", description: "test", creator: @user)
    end
  end
end
