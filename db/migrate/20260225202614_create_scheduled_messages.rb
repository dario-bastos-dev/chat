class CreateScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      
      t.string :title, null: false
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.integer :status, default: 0, null: false # pending: 0, sent: 1, cancelled: 2
      
      t.timestamps
    end

    add_index :scheduled_messages, [:account_id, :status, :scheduled_at], name: 'idx_sched_msgs_dispatch'
  end
end
