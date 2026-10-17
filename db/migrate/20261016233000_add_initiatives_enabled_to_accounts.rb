class AddInitiativesEnabledToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :initiatives_enabled, :boolean, default: true, null: false
  end
end
