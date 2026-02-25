# frozen_string_literal: true

class AddLeadFieldsToContacts < ActiveRecord::Migration[7.0]
  def change
    change_table :contacts, bulk: true do |t|
      t.boolean :is_lead, default: false
      t.string :lead_source, limit: 100
      t.integer :lead_score, default: 0
    end

    add_index :contacts, [:account_id, :is_lead], name: 'index_contacts_on_account_id_and_is_lead'
    add_index :contacts, [:account_id, :lead_score], name: 'index_contacts_on_account_id_and_lead_score'
  end
end
