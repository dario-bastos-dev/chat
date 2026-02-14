# frozen_string_literal: true

class CreateConversationDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_deals do |t|
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :deal, null: false, foreign_key: true, index: true
      t.boolean :is_primary, default: false

      t.timestamps
    end

    add_index :conversation_deals, [:conversation_id, :deal_id], 
              unique: true, 
              name: 'index_conversation_deals_unique'
  end
end
