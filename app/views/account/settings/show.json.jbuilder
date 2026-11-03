json.(@account, :id, :name, :cards_count, :initiatives_enabled)
json.created_at @account.created_at.utc
json.auto_postpone_period_in_days @account.entropy.auto_postpone_period_in_days
