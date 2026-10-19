require "test_helper"

class Initiatives::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @initiative = Tag.create!(title: "launch-platform", start_date: Date.current, end_date: Date.current + 4.weeks)
    @checkpoint = @initiative.checkpoints.create!(content: "Design mockups")
  end

  test "create checkpoint via turbo stream" do
    assert_difference -> { @initiative.checkpoints.count } => 1, -> { @initiative.activities.count } => 1 do
      post initiative_checkpoints_path(@initiative), params: { checkpoint: { content: "Build prototype" } }, as: :turbo_stream
    end
    assert_response :success
    assert_equal "milestone_added", @initiative.activities.first.action
    assert_match "initiative_checkpoints_#{@initiative.id}", response.body
    assert_match "timeline_bar_fill", response.body
  end

  test "complete checkpoint via turbo stream does not expand row" do
    assert_difference -> { @initiative.activities.count } => 1 do
      patch initiative_checkpoint_path(@initiative, @checkpoint), params: { checkpoint: { completed: true } }, as: :turbo_stream
    end
    assert_response :success
    assert @checkpoint.reload.completed?
    assert_equal 100, @initiative.reload.progress_percentage
    assert_equal "milestone_completed", @initiative.activities.first.action
    assert_match "initiative_checkpoints_#{@initiative.id}", response.body
    assert_match "timeline_bar_fill", response.body
    assert_match "timeline_bar_meta", response.body
    assert_no_match "timeline-row", response.body # Never replaces the entire row
  end

  test "destroy checkpoint via turbo stream" do
    assert_difference -> { @initiative.checkpoints.count } => -1, -> { @initiative.activities.count } => 1 do
      delete initiative_checkpoint_path(@initiative, @checkpoint), as: :turbo_stream
    end
    assert_response :success
    assert_equal "milestone_removed", @initiative.activities.first.action
    assert_match "initiative_checkpoints_#{@initiative.id}", response.body
  end

  test "returns not found when initiatives are disabled for account" do
    Current.account.update!(initiatives_enabled: false)
    post initiative_checkpoints_path(@initiative), params: { checkpoint: { content: "Hidden milestone" } }
    assert_response :not_found
  end

  test "non-admin cannot create, update, or destroy checkpoints" do
    logout_and_sign_in_as :david

    post initiative_checkpoints_path(@initiative), params: { checkpoint: { content: "Unauthorized milestone" } }
    assert_response :forbidden

    patch initiative_checkpoint_path(@initiative, @checkpoint), params: { checkpoint: { completed: true } }
    assert_response :forbidden

    delete initiative_checkpoint_path(@initiative, @checkpoint)
    assert_response :forbidden
  end

  test "create checkpoint returns unprocessable_entity on blank content" do
    post initiative_checkpoints_path(@initiative), params: { checkpoint: { content: "" } }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_match "can&#39;t be blank", response.body
  end
end
