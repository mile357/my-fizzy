require "test_helper"

class InitiativesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @initiative = Tag.create!(title: "test-init", start_date: Date.current, end_date: Date.current + 2.weeks)
  end

  test "index" do
    get initiatives_path
    assert_response :success
    assert_match "Timeline", response.body
    assert_match "Tags", response.body
    assert_match "All (", response.body
    assert_match "New (", response.body
    assert_match "Recent (", response.body
    assert_match "tag-pill--initiative", response.body
    assert_match "btn--add-tag-pill", response.body
    assert_match "tag-filter-pill", response.body
    assert_select ".timeline-header__title", text: "Timeline"
  end

  test "show" do
    get initiative_path(@initiative)
    assert_response :success
  end

  test "create" do
    assert_difference -> { Tag.count } => 1, -> { InitiativeActivity.count } => 1 do
      post initiatives_path, params: { tag: { title: "brand-new-init", start_date: Date.current, end_date: Date.current + 1.week } }
    end
    assert_redirected_to initiatives_path(initiative_id: Tag.last.id)
    assert_equal "initiative_created", InitiativeActivity.last.action
  end

  test "create via turbo stream" do
    assert_difference -> { Tag.count } => 1, -> { InitiativeActivity.count } => 1 do
      post initiatives_path, params: { tag: { title: "turbo-init", start_date: Date.current, end_date: Date.current + 1.week } }, as: :turbo_stream
    end
    assert_response :success
    assert_match "timeline_grid", response.body
    assert_match "initiative_inspector", response.body
    assert_match "unscheduled_tags_tray", response.body
  end

  test "create unscheduled tag without dates via turbo stream" do
    assert_difference -> { Tag.count } => 1, -> { InitiativeActivity.count } => 1 do
      post initiatives_path, params: { tag: { title: "just-a-tag" } }, as: :turbo_stream
    end
    assert_response :success
    created_tag = Tag.find_by!(title: "just-a-tag")
    assert_nil created_tag.start_date
    assert_nil created_tag.end_date
    assert_equal "tag_created", created_tag.activities.first.action
    assert_match "unscheduled_tags_tray", response.body
    assert_match "just-a-tag", response.body
    assert_match "Add to Timeline", response.body
  end

  test "destroy via turbo stream" do
    assert_difference -> { @initiative.activities.count } => 1 do
      delete initiative_path(@initiative), as: :turbo_stream
    end
    assert_response :success
    assert_nil @initiative.reload.start_date
    assert_nil @initiative.reload.end_date
    assert_nil @initiative.reload.color
    assert_not @initiative.reload.initiative?
    assert_equal "timeline_cleared", @initiative.activities.first.action
    assert_match "timeline_grid", response.body
    assert_match "initiative_inspector", response.body
    assert_match "unscheduled_tags_tray", response.body
  end

  test "update via turbo stream" do
    patch initiative_path(@initiative), params: { tag: { color: "#10b981" } }, as: :turbo_stream
    assert_response :success
    assert_equal "#10b981", @initiative.reload.color
    assert_match "timeline_grid", response.body
  end

  test "update dates records activity and renders deadline marker" do
    assert_difference -> { @initiative.activities.count } => 1 do
      patch initiative_path(@initiative), params: { tag: { end_date: Date.current + 3.months } }, as: :turbo_stream
    end
    assert_response :success
    assert_equal "dates_changed", @initiative.activities.first.action
    assert_match "timeline-bar__deadline-marker", response.body
  end

  test "show via turbo stream" do
    get initiative_path(@initiative), as: :turbo_stream
    assert_response :success
    assert_match "timeline_grid", response.body
    assert_match "initiative_inspector", response.body
  end

  test "redirects to root when initiatives are disabled for account" do
    Current.account.update!(initiatives_enabled: false)
    get initiatives_path
    assert_redirected_to root_path
    assert_equal "Cross-Board Initiatives are disabled for this account.", flash[:alert]
  end

  test "index packs non-overlapping initiatives into the same lane" do
    Tag.create!(title: "next-init", start_date: @initiative.end_date + 1.day, end_date: @initiative.end_date + 2.weeks)
    get initiatives_path
    assert_response :success
    assert_select "#timeline_lane_0 .timeline-bar", count: 2
    assert_select "#timeline_lane_1", count: 0
  end
end
