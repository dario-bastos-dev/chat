class CreateChannelWhatsappLidMappings < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_whatsapp_lid_mappings do |t|
      t.string :lid, null: false
      t.string :phone_number, null: false
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # Primary lookup: find contact by LID within an account
    add_index :channel_whatsapp_lid_mappings, [:account_id, :lid], unique: true,
              name: 'index_whatsapp_lid_mappings_on_account_and_lid'

    # Reverse lookup: find LIDs by phone number
    add_index :channel_whatsapp_lid_mappings, [:account_id, :phone_number],
              name: 'index_whatsapp_lid_mappings_on_account_and_phone'

    # Lookup by inbox and contact
    add_index :channel_whatsapp_lid_mappings, [:inbox_id, :contact_id],
              name: 'index_whatsapp_lid_mappings_on_inbox_and_contact'
  end
end
