# frozen_string_literal: true

class CreateDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :deals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :stage, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :inbox, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }

      t.string :title, null: false, limit: 500
      t.decimal :value, precision: 15, scale: 2, default: 0.00
      t.string :currency, limit: 3, default: 'BRL'
      t.string :status, limit: 50, default: 'open'
      t.string :lost_reason, limit: 255
      t.jsonb :custom_attributes, default: {}
      t.datetime :last_activity_at
      t.datetime :won_at
      t.datetime :lost_at
      t.date :expected_close_date
      t.integer :position, default: 0

      t.timestamps
    end

    # Performance indexes for Kanban listing
    add_index :deals, [:account_id, :pipeline_id, :stage_id, :status], 
              name: 'idx_deals_kanban_listing'
    add_index :deals, [:account_id, :assignee_id, :status], 
              name: 'idx_deals_by_assignee'
    add_index :deals, [:contact_id, :status], 
              name: 'idx_deals_by_contact'
    add_index :deals, :status
    add_index :deals, :last_activity_at

    # Partial index for open deals (most queried)
    add_index :deals, [:account_id, :pipeline_id, :stage_id], 
              where: "status = 'open'", 
              name: 'idx_deals_open_only'

    # GIN index for JSONB custom attributes
    add_index :deals, :custom_attributes, using: :gin, 
              name: 'idx_deals_custom_attrs_gin'
  end
end
