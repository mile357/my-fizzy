class AddInitiativeFieldsToTagsAndCreateCheckpoints < ActiveRecord::Migration[8.2]
  def change
    change_table :tags do |t|
      t.date :start_date
      t.date :end_date
      t.string :color
      t.index [ :account_id, :end_date ]
    end

    create_table :checkpoints, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :tag_id, null: false
      t.text :content, null: false
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at

      t.timestamps

      t.index :account_id
      t.index :tag_id
      t.index [ :tag_id, :completed ]
    end
  end
end
