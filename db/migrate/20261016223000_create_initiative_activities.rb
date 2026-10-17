class CreateInitiativeActivities < ActiveRecord::Migration[8.2]
  def change
    create_table :initiative_activities, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :tag_id, null: false
      t.uuid :creator_id, null: false
      t.string :action, null: false
      t.string :description, null: false
      t.json :particulars, default: {}

      t.timestamps

      t.index :account_id
      t.index [ :tag_id, :created_at ]
      t.index [ :account_id, :created_at ]
    end
  end
end
