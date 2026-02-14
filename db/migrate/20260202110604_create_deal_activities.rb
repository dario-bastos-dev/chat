# frozen_string_literal: true

class CreateDealActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_activities do |t|
      t.references :deal, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, foreign_key: true, index: true

      t.string :activity_type, limit: 50, null: false
      t.text :description
      t.datetime :due_date
      t.datetime :completed_at

      t.timestamps
    end

    add_index :deal_activities, :due_date
    add_index :deal_activities, [:deal_id, :activity_type], name: 'idx_deal_activities_by_type'
  end
end
