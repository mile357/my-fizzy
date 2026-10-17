require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    sign_in_as :kevin
  end

  test "show displays features section with initiatives toggle" do
    get account_settings_path
    assert_response :success
    assert_match "Features", response.body
    assert_match "Cross-Board Initiatives", response.body
    assert_match "account[initiatives_enabled]", response.body
  end

  test "admin can toggle initiatives off" do
    assert @account.initiatives_enabled?

    put account_settings_path, params: { account: { initiatives_enabled: false } }
    assert_redirected_to account_settings_path

    assert_not @account.reload.initiatives_enabled?
  end

  test "admin can toggle initiatives using form parameter strings" do
    assert @account.initiatives_enabled?

    put account_settings_path, params: { account: { initiatives_enabled: "0" } }
    assert_redirected_to account_settings_path
    assert_not @account.reload.initiatives_enabled?

    put account_settings_path, params: { account: { initiatives_enabled: "1" } }
    assert_redirected_to account_settings_path
    assert @account.reload.initiatives_enabled?
  end

  test "admin can toggle initiatives back on without data loss" do
    tag = Tag.create!(account: @account, title: "road-map", start_date: Date.current, end_date: Date.current + 1.month, color: "#3b82f6")
    cp = tag.checkpoints.create!(content: "Checkpoint 1", completed: true)

    # Disable
    put account_settings_path, params: { account: { initiatives_enabled: false } }
    assert_not @account.reload.initiatives_enabled?

    # Verify data is preserved
    assert_equal Date.current, tag.reload.start_date
    assert_equal "#3b82f6", tag.color
    assert_equal 1, tag.checkpoints.count

    # Re-enable
    put account_settings_path, params: { account: { initiatives_enabled: true } }
    assert @account.reload.initiatives_enabled?

    # Verify intact
    assert_equal Date.current, tag.reload.start_date
    assert_equal 1, tag.reload.checkpoints.count
    assert cp.reload.completed?
  end

  test "non-admin cannot update initiatives_enabled" do
    logout_and_sign_in_as :david

    put account_settings_path, params: { account: { initiatives_enabled: false } }
    assert_response :forbidden
    assert @account.reload.initiatives_enabled?
  end
end
